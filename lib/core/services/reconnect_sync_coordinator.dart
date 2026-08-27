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
  ref.listen<AsyncValue<ConnectivityStatus>>(connectivityProvider,
      (previous, next) {
    final status = next.valueOrNull;
    if (status == ConnectivityStatus.offline) {
      ref.read(reconnectSyncStatusProvider.notifier).state =
          ReconnectSyncStatus.offline;
      return;
    }
    if (status == ConnectivityStatus.online &&
        previous?.valueOrNull != ConnectivityStatus.online) {
      unawaited(_syncAfterReconnect(ref));
    }
  }, fireImmediately: true);
});

Future<void> _syncAfterReconnect(Ref ref) async {
  ref.read(reconnectSyncStatusProvider.notifier).state =
      ReconnectSyncStatus.checking;
  final auth = ref.read(authProvider);
  try {
    await ref.read(apiClientProvider).get(
          auth.isLoggedIn ? ApiEndpoints.syncStatus : ApiEndpoints.mapLocations,
        );
  } catch (_) {
    ref.read(reconnectSyncStatusProvider.notifier).state =
        ReconnectSyncStatus.failed;
    return;
  }

  ref.read(reconnectSyncStatusProvider.notifier).state =
      ReconnectSyncStatus.syncing;
  if (auth.isLoggedIn) {
    await SyncService.instance.triggerSyncAll();
    await ref.read(itineraryRepositoryProvider).flushPendingMutations();
    await ref.read(favoriteKeysProvider.notifier).reload();
  }

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
