import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../core/constants/app_constants.dart';
import '../../core/location/tubigon_boundary.dart';
import '../../core/network/connectivity_provider.dart';
import '../../core/services/local_storage_service.dart';
import '../authentication/auth_provider.dart';
import '../emergency/repositories/emergency_repository.dart';
import '../favorites/repositories/favorites_repository.dart';
import '../ferry/repositories/ferry_repository.dart';
import '../itinerary/repositories/itinerary_repository.dart';
import '../map/providers/map_provider.dart';
import '../reservations/repositories/reservation_repository.dart';

enum OfflinePackagePhase {
  idle,
  downloadingData,
  downloadingMap,
  paused,
  ready,
  failed,
  deleting,
}

class OfflineMapState {
  const OfflineMapState({
    this.phase = OfflinePackagePhase.idle,
    this.dataReady = false,
    this.baseMapReady = false,
    this.mapProgress,
    this.regionId,
    this.downloadedAt,
    this.lastSyncedAt,
    this.placeCount = 0,
    this.placeDataBytes = 0,
    this.mapResourceBytes = 0,
    this.error,
  });

  final OfflinePackagePhase phase;
  final bool dataReady;
  final bool baseMapReady;
  final double? mapProgress;
  final int? regionId;
  final DateTime? downloadedAt;
  final DateTime? lastSyncedAt;
  final int placeCount;
  final int placeDataBytes;
  final int mapResourceBytes;
  final String? error;

  bool get isBusy => phase == OfflinePackagePhase.downloadingData ||
      phase == OfflinePackagePhase.downloadingMap ||
      phase == OfflinePackagePhase.deleting;
  bool get canOpen => dataReady;
  int get totalBytes => placeDataBytes + mapResourceBytes;

  OfflineMapState copyWith({
    OfflinePackagePhase? phase,
    bool? dataReady,
    bool? baseMapReady,
    double? mapProgress,
    bool clearProgress = false,
    int? regionId,
    bool clearRegion = false,
    DateTime? downloadedAt,
    DateTime? lastSyncedAt,
    int? placeCount,
    int? placeDataBytes,
    int? mapResourceBytes,
    String? error,
    bool clearError = false,
  }) =>
      OfflineMapState(
        phase: phase ?? this.phase,
        dataReady: dataReady ?? this.dataReady,
        baseMapReady: baseMapReady ?? this.baseMapReady,
        mapProgress: clearProgress ? null : mapProgress ?? this.mapProgress,
        regionId: clearRegion ? null : regionId ?? this.regionId,
        downloadedAt: downloadedAt ?? this.downloadedAt,
        lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
        placeCount: placeCount ?? this.placeCount,
        placeDataBytes: placeDataBytes ?? this.placeDataBytes,
        mapResourceBytes: mapResourceBytes ?? this.mapResourceBytes,
        error: clearError ? null : error ?? this.error,
      );

  Map<String, dynamic> toJson() => {
        'package_version': 1,
        'data_ready': dataReady,
        'base_map_ready': baseMapReady,
        'region_id': regionId,
        'downloaded_at': downloadedAt?.toIso8601String(),
        'last_synced_at': lastSyncedAt?.toIso8601String(),
        'place_count': placeCount,
        'place_data_bytes': placeDataBytes,
        'map_resource_bytes': mapResourceBytes,
        'map_resource_version': baseMapReady ? AppConstants.mapStyleUrl : null,
      };

  factory OfflineMapState.fromJson(Map<String, dynamic> json) {
    final dataReady = json['data_ready'] == true;
    final baseMapReady = json['base_map_ready'] == true;
    return OfflineMapState(
      phase: dataReady ? OfflinePackagePhase.ready : OfflinePackagePhase.idle,
      dataReady: dataReady,
      baseMapReady: baseMapReady,
      regionId: (json['region_id'] as num?)?.toInt(),
      downloadedAt: DateTime.tryParse(json['downloaded_at']?.toString() ?? ''),
      lastSyncedAt:
          DateTime.tryParse(json['last_synced_at']?.toString() ?? ''),
      placeCount: (json['place_count'] as num?)?.toInt() ?? 0,
      placeDataBytes: (json['place_data_bytes'] as num?)?.toInt() ?? 0,
      mapResourceBytes: (json['map_resource_bytes'] as num?)?.toInt() ?? 0,
    );
  }
}

class OfflineMapNotifier extends StateNotifier<OfflineMapState> {
  OfflineMapNotifier(this._ref) : super(const OfflineMapState()) {
    _restore();
  }

  static const _metadataKey = 'tubigon_offline_package_metadata_v1';
  final Ref _ref;

  static bool get supportsNativeMapResources => !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> _restore() async {
    final raw = LocalStorageService.instance.getString(_metadataKey);
    if (raw == null) return;
    try {
      state = OfflineMapState.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
      if (supportsNativeMapResources && state.regionId != null) {
        final status = await getOfflineRegionStatus(state.regionId!);
        state = state.copyWith(
          baseMapReady: status.isComplete,
          mapProgress: status.downloadProgress,
          mapResourceBytes: status.completedResourceSize,
        );
      }
    } catch (error) {
      debugPrint('[OFFLINE MAP] Unable to restore package metadata: $error');
    }
  }

  Future<void> downloadOrUpdate() async {
    if (state.isBusy) return;
    if (!await checkConnectivity()) {
      state = state.copyWith(
        phase: OfflinePackagePhase.failed,
        error: 'Connect to the internet to download the Tubigon offline map.',
      );
      return;
    }
    state = state.copyWith(
      phase: OfflinePackagePhase.downloadingData,
      clearError: true,
      mapProgress: 0,
    );
    try {
      final auth = _ref.read(authProvider);
      final markers = await _ref.read(mapRepositoryProvider).getLocations(auth);
      final categories = await _ref.read(mapRepositoryProvider).getCategories();

      // These repositories use their existing native/user-scoped caches. A
      // failed optional snapshot does not invalidate the essential place data.
      await _bestEffort(() =>
          _ref.read(emergencyRepositoryProvider).getEmergencyContacts());
      await _bestEffort(
          () => _ref.read(ferryRepositoryProvider).getFerrySchedules());
      if (auth.isLoggedIn) {
        await _bestEffort(
            () => _ref.read(itineraryRepositoryProvider).getItineraries());
        await _bestEffort(
            () => _ref.read(reservationRepositoryProvider).getReservations());
        await _bestEffort(
            () => _ref.read(favoriteKeysProvider.notifier).reload());
      }

      final dataBytes = utf8.encode(jsonEncode({
        'places': markers.map((item) => item.toJson()).toList(),
        'categories': categories.map((item) => item.toJson()).toList(),
      })).length;
      final now = DateTime.now();
      state = state.copyWith(
        dataReady: true,
        downloadedAt: state.downloadedAt ?? now,
        lastSyncedAt: now,
        placeCount: markers.length,
        placeDataBytes: dataBytes,
      );
      await _persist();

      if (!supportsNativeMapResources) {
        state = state.copyWith(
          phase: OfflinePackagePhase.ready,
          baseMapReady: false,
          clearProgress: true,
        );
        await _persist();
        return;
      }

      if (state.regionId != null && state.baseMapReady) {
        // Public and personal snapshots were refreshed. MapLibre owns its
        // persistent region and can reuse unchanged resources.
        state = state.copyWith(phase: OfflinePackagePhase.ready);
        await _persist();
        return;
      }

      state = state.copyWith(
        phase: OfflinePackagePhase.downloadingMap,
        mapProgress: 0,
      );
      final region = await downloadOfflineRegion(
        OfflineRegionDefinition(
          bounds: LatLngBounds(
            southwest: const LatLng(
              TubigonBoundary.minLatitude,
              TubigonBoundary.minLongitude,
            ),
            northeast: const LatLng(
              TubigonBoundary.maxLatitude,
              TubigonBoundary.maxLongitude,
            ),
          ),
          mapStyleUrl: AppConstants.mapStyleUrl,
          minZoom: 10,
          maxZoom: 16,
        ),
        metadata: const {
          'package': 'tubigon',
          'package_version': 1,
        },
        onEvent: _onMapDownloadEvent,
      );
      state = state.copyWith(regionId: region.id);
      await _persist();
    } catch (error) {
      debugPrint('[OFFLINE MAP] Download failed: $error');
      state = state.copyWith(
        phase: OfflinePackagePhase.failed,
        error: state.dataReady
            ? 'Place data is saved, but map resources could not be downloaded.'
            : 'Unable to download the offline map.',
      );
      await _persist();
    }
  }

  void _onMapDownloadEvent(DownloadRegionStatus event) {
    if (event is InProgress) {
      state = state.copyWith(
        phase: OfflinePackagePhase.downloadingMap,
        mapProgress: event.progress.clamp(0, 100),
        mapResourceBytes: event.completedResourceSize,
        clearError: true,
      );
    } else if (event is Success) {
      state = state.copyWith(
        phase: OfflinePackagePhase.ready,
        baseMapReady: true,
        mapProgress: 100,
        lastSyncedAt: DateTime.now(),
        clearError: true,
      );
      _persist();
    } else if (event is Error) {
      state = state.copyWith(
        phase: OfflinePackagePhase.failed,
        error: 'Map resource download was interrupted. You can retry.',
      );
      _persist();
    }
  }

  Future<void> pause() async {
    final id = state.regionId;
    if (!supportsNativeMapResources || id == null) return;
    await pauseOfflineRegionDownload(id);
    state = state.copyWith(phase: OfflinePackagePhase.paused);
  }

  Future<void> resume() async {
    final id = state.regionId;
    if (!supportsNativeMapResources || id == null) {
      await downloadOrUpdate();
      return;
    }
    await resumeOfflineRegionDownload(id);
    state = state.copyWith(
      phase: OfflinePackagePhase.downloadingMap,
      clearError: true,
    );
  }

  Future<void> deletePackage() async {
    if (state.isBusy) return;
    state = state.copyWith(phase: OfflinePackagePhase.deleting);
    try {
      if (supportsNativeMapResources && state.regionId != null) {
        await deleteOfflineRegion(state.regionId!);
        await clearAmbientCache();
      }
      final storage = LocalStorageService.instance;
      await storage.remove(_metadataKey);
      await storage.remove('smart_map_cache_tourist');
      await storage.remove('smart_map_cache_guest');
      await storage.remove('smart_map_categories_cache');
      state = const OfflineMapState();
      _ref.invalidate(mapMarkersProvider);
      _ref.invalidate(mapPlaceCategoriesProvider);
    } catch (error) {
      state = state.copyWith(
        phase: OfflinePackagePhase.failed,
        error: 'Unable to delete the offline map right now.',
      );
    }
  }

  Future<void> _persist() => LocalStorageService.instance.setString(
        _metadataKey,
        jsonEncode(state.toJson()),
      );

  Future<void> _bestEffort(Future<dynamic> Function() operation) async {
    try {
      await operation();
    } catch (error) {
      debugPrint('[OFFLINE MAP] Optional snapshot unavailable: $error');
    }
  }
}

final offlineMapProvider =
    StateNotifierProvider<OfflineMapNotifier, OfflineMapState>((ref) {
  return OfflineMapNotifier(ref);
});
