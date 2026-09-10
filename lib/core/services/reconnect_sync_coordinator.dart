import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/authentication/auth_provider.dart';
import '../../features/emergency/repositories/emergency_repository.dart';
import '../../features/favorites/repositories/favorites_repository.dart';
import '../../features/ferry/repositories/ferry_repository.dart';
import '../../features/itinerary/repositories/itinerary_repository.dart';
import '../../features/map/providers/map_provider.dart';
import '../../features/notifications/repositories/notification_repository.dart';
import '../../features/reservations/repositories/reservation_repository.dart';
import '../constants/api_endpoints.dart';
import '../network/api_client.dart';
import '../network/connectivity_provider.dart';
import 'sync_service.dart';

enum ReconnectSyncStatus { offline, checking, syncing, online, failed }

final reconnectSyncStatusProvider =
    StateProvider<ReconnectSyncStatus>((ref) => ReconnectSyncStatus.checking);

/// Initializes one app-wide reconnect listener. Network-interface availability
/// is followed by a real Laravel request before any queued writes are flushed.
final reconnectSyncCoordinatorProvider = Provider<void>((ref) {
  var disposed = false;
  Future<void>? activeSync;
  ref.onDispose(() => disposed = true);

  void startSync() {
    if (disposed || activeSync != null) return;
    final operation = _syncAfterReconnect(ref, () => !disposed);
    activeSync = operation;
    unawaited(operation.whenComplete(() {
      if (identical(activeSync, operation)) activeSync = null;
    }));
  }

  ref.listen<AsyncValue<ConnectivityStatus>>(connectivityProvider,
      (previous, next) {
    if (disposed) return;
    final status = next.valueOrNull;
    if (status == ConnectivityStatus.offline) {
      ref.read(reconnectSyncStatusProvider.notifier).state =
          ReconnectSyncStatus.offline;
      return;
    }
    if (status == ConnectivityStatus.online &&
        previous?.valueOrNull != ConnectivityStatus.online) {
      startSync();
    }
  }, fireImmediately: true);
});

Future<void> _syncAfterReconnect(Ref ref, bool Function() isActive) async {
  if (!isActive()) return;
  ref.read(reconnectSyncStatusProvider.notifier).state =
      ReconnectSyncStatus.checking;
  var auth = ref.read(authProvider);
  try {
    if (auth.isLoggedIn) {
      // Revalidate the token and refresh the authoritative role before any
      // locally queued Tourist mutation is considered for upload.
      await ref.read(authProvider.notifier).reloadProfile();
      if (!isActive()) return;
      auth = ref.read(authProvider);
      if (!auth.isLoggedIn || auth.isOfflineSession) {
        ref.read(reconnectSyncStatusProvider.notifier).state =
            ReconnectSyncStatus.failed;
        return;
      }
    } else {
      await ref.read(apiClientProvider).get(ApiEndpoints.mapLocations);
      if (!isActive()) return;
    }
  } catch (_) {
    if (!isActive()) return;
    ref.read(reconnectSyncStatusProvider.notifier).state =
        ReconnectSyncStatus.failed;
    return;
  }

  if (!isActive()) return;
  ref.read(reconnectSyncStatusProvider.notifier).state =
      ReconnectSyncStatus.syncing;
  if (auth.isLoggedIn) {
    await SyncService.instance.triggerSyncAll();
    if (!isActive()) return;
    await ref.read(itineraryRepositoryProvider).flushPendingMutations();
    if (!isActive()) return;
    await ref.read(favoriteKeysProvider.notifier).reload();
    if (!isActive()) return;
  }

  if (!isActive()) return;
  ref.invalidate(mapMarkersProvider);
  ref.invalidate(mapPlaceCategoriesProvider);
  ref.invalidate(emergencyContactsListProvider);
  ref.invalidate(ferrySchedulesListProvider);
  if (auth.isLoggedIn) {
    ref.invalidate(itinerariesProvider);
    ref.invalidate(reservationsListProvider);
    ref.invalidate(touristNotificationsProvider);
    ref.invalidate(touristUnreadCountProvider);
  }
  ref.read(reconnectSyncStatusProvider.notifier).state =
      ReconnectSyncStatus.online;
}
