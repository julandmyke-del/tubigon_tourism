import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../core/constants/app_constants.dart';
import '../../core/location/tubigon_boundary.dart';
import '../../core/network/connectivity_provider.dart';
import '../../core/services/local_storage_service.dart';
import '../../core/services/private_session_data_service.dart';
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
  validating,
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
    this.pendingRegionId,
    this.mapResourceVersion,
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
  final int? pendingRegionId;
  final String? mapResourceVersion;
  final DateTime? downloadedAt;
  final DateTime? lastSyncedAt;
  final int placeCount;
  final int placeDataBytes;
  final int mapResourceBytes;
  final String? error;

  bool get isBusy =>
      phase == OfflinePackagePhase.downloadingData ||
      phase == OfflinePackagePhase.downloadingMap ||
      phase == OfflinePackagePhase.validating ||
      phase == OfflinePackagePhase.deleting;
  bool get canOpen => dataReady && baseMapReady;
  bool get hasDataSnapshot => dataReady;
  int get totalBytes => placeDataBytes + mapResourceBytes;

  OfflineMapState copyWith({
    OfflinePackagePhase? phase,
    bool? dataReady,
    bool? baseMapReady,
    double? mapProgress,
    bool clearProgress = false,
    int? regionId,
    bool clearRegion = false,
    int? pendingRegionId,
    bool clearPendingRegion = false,
    String? mapResourceVersion,
    bool clearMapResourceVersion = false,
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
        pendingRegionId:
            clearPendingRegion ? null : pendingRegionId ?? this.pendingRegionId,
        mapResourceVersion: clearMapResourceVersion
            ? null
            : mapResourceVersion ?? this.mapResourceVersion,
        downloadedAt: downloadedAt ?? this.downloadedAt,
        lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
        placeCount: placeCount ?? this.placeCount,
        placeDataBytes: placeDataBytes ?? this.placeDataBytes,
        mapResourceBytes: mapResourceBytes ?? this.mapResourceBytes,
        error: clearError ? null : error ?? this.error,
      );

  Map<String, dynamic> toJson() => {
        'package_version': 2,
        'data_ready': dataReady,
        'base_map_ready': baseMapReady,
        'region_id': regionId,
        'pending_region_id': pendingRegionId,
        'downloaded_at': downloadedAt?.toIso8601String(),
        'last_synced_at': lastSyncedAt?.toIso8601String(),
        'place_count': placeCount,
        'place_data_bytes': placeDataBytes,
        'map_resource_bytes': mapResourceBytes,
        'map_resource_version': mapResourceVersion,
      };

  factory OfflineMapState.fromJson(Map<String, dynamic> json) {
    final dataReady = json['data_ready'] == true;
    final baseMapReady = json['base_map_ready'] == true;
    return OfflineMapState(
      phase: dataReady ? OfflinePackagePhase.ready : OfflinePackagePhase.idle,
      dataReady: dataReady,
      baseMapReady: baseMapReady,
      regionId: (json['region_id'] as num?)?.toInt(),
      pendingRegionId: (json['pending_region_id'] as num?)?.toInt(),
      mapResourceVersion: json['map_resource_version']?.toString(),
      downloadedAt: DateTime.tryParse(json['downloaded_at']?.toString() ?? ''),
      lastSyncedAt: DateTime.tryParse(json['last_synced_at']?.toString() ?? ''),
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
  static const packageVersion = 2;
  final Ref _ref;
  int? _monitoredRegionId;
  int _retainedMapResourceBytes = 0;

  static bool get supportsNativeMapResources =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> _restore() async {
    final raw = LocalStorageService.instance.getString(_metadataKey);
    if (raw == null) return;
    try {
      state = OfflineMapState.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
      if (supportsNativeMapResources) {
        if (state.regionId != null) {
          final status = await getOfflineRegionStatus(state.regionId!);
          state = state.copyWith(
            baseMapReady: _isValid(status),
            mapProgress: status.downloadProgress,
            mapResourceBytes: status.completedResourceSize,
          );
        }
        if (state.pendingRegionId != null) {
          final pending = await getOfflineRegionStatus(state.pendingRegionId!);
          if (_isValid(pending)) {
            await _promoteRegion(state.pendingRegionId!, pending);
          } else {
            state = state.copyWith(
              phase: OfflinePackagePhase.paused,
              mapProgress: pending.downloadProgress,
            );
          }
        }
      }
      await _persist();
    } catch (error) {
      debugPrint('[OFFLINE MAP] Unable to restore package metadata: $error');
      if (supportsNativeMapResources) {
        state = state.copyWith(
          phase: OfflinePackagePhase.failed,
          baseMapReady: false,
          clearRegion: true,
          clearPendingRegion: true,
          clearMapResourceVersion: true,
          error: 'offline_error_restore',
        );
        await _persist();
      }
    }
  }

  Future<void> downloadOrUpdate() async {
    if (state.isBusy) return;
    if (!await checkConnectivity()) {
      state = state.copyWith(
        phase: OfflinePackagePhase.failed,
        error: 'offline_error_connection_required',
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
      await _bestEffort(
          () => _ref.read(emergencyRepositoryProvider).getEmergencyContacts());
      await _bestEffort(
          () => _ref.read(ferryRepositoryProvider).getFerrySchedules());
      if (auth.isLoggedIn) {
        final trips =
            await _ref.read(itineraryRepositoryProvider).getItineraries();
        for (final trip in trips) {
          await _bestEffort(() =>
              _ref.read(itineraryRepositoryProvider).getItinerary(trip.id));
        }
        await _bestEffort(
            () => _ref.read(reservationRepositoryProvider).getReservations());
        await _bestEffort(
            () => _ref.read(favoriteKeysProvider.notifier).reload());
      }

      final dataBytes = utf8
          .encode(jsonEncode({
            'places': markers.map((item) => item.toJson()).toList(),
            'categories': categories.map((item) => item.toJson()).toList(),
          }))
          .length;
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

      if (state.regionId != null &&
          state.baseMapReady &&
          state.mapResourceVersion == AppConstants.mapStyleUrl) {
        // Public and personal snapshots were refreshed. MapLibre owns its
        // persistent region and can reuse unchanged resources.
        state = state.copyWith(phase: OfflinePackagePhase.ready);
        await _persist();
        return;
      }

      _retainedMapResourceBytes =
          state.baseMapReady ? state.mapResourceBytes : 0;
      state = state.copyWith(
        phase: OfflinePackagePhase.downloadingMap,
        mapProgress: 0,
        mapResourceBytes: _retainedMapResourceBytes,
      );
      int? candidateRegionId;
      DownloadRegionStatus? pendingTerminalEvent;
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
          'package_version': packageVersion,
          'map_resource_version': AppConstants.mapStyleUrl,
        },
        onEvent: (event) {
          if (candidateRegionId == null &&
              (event is Success || event is Error)) {
            pendingTerminalEvent = event;
            return;
          }
          _onMapDownloadEvent(event, candidateRegionId);
        },
      );
      candidateRegionId = region.id;
      state = state.copyWith(pendingRegionId: region.id);
      await _persist();
      if (pendingTerminalEvent != null) {
        _onMapDownloadEvent(pendingTerminalEvent!, region.id);
      }
    } catch (error) {
      debugPrint('[OFFLINE MAP] Download failed: $error');
      state = state.copyWith(
        phase: OfflinePackagePhase.failed,
        error: state.dataReady
            ? 'offline_error_map_resources'
            : 'offline_error_download',
      );
      await _persist();
    }
  }

  void _onMapDownloadEvent(DownloadRegionStatus event, int? candidateId) {
    if (event is InProgress) {
      state = state.copyWith(
        phase: OfflinePackagePhase.downloadingMap,
        mapProgress: event.progress.clamp(0, 100),
        mapResourceBytes: event.completedResourceSize,
        clearError: true,
      );
    } else if (event is Success) {
      state = state.copyWith(
        phase: OfflinePackagePhase.validating,
        mapProgress: 100,
        clearError: true,
      );
      if (candidateId != null) {
        _validateAndPromote(candidateId);
      }
    } else if (event is Error) {
      _failPendingDownload(candidateId, 'offline_error_interrupted');
    }
  }

  Future<void> _validateAndPromote(int candidateId) async {
    try {
      final status = await getOfflineRegionStatus(candidateId);
      if (!_isValid(status)) {
        await _failPendingDownload(
          candidateId,
          'offline_error_validation',
        );
        return;
      }
      await _promoteRegion(candidateId, status);
    } catch (error) {
      debugPrint('[OFFLINE MAP] Validation failed: $error');
      await _failPendingDownload(
        candidateId,
        'offline_error_validation',
      );
    }
  }

  bool _isValid(OfflineRegionStatus status) =>
      status.isComplete &&
      status.completedResourceCount > 0 &&
      status.completedResourceSize > 0;

  Future<void> _promoteRegion(
    int candidateId,
    OfflineRegionStatus status,
  ) async {
    final previousId = state.regionId;
    state = state.copyWith(
      phase: OfflinePackagePhase.ready,
      regionId: candidateId,
      clearPendingRegion: true,
      baseMapReady: true,
      mapProgress: 100,
      mapResourceBytes: status.completedResourceSize,
      mapResourceVersion: AppConstants.mapStyleUrl,
      downloadedAt: state.downloadedAt ?? DateTime.now(),
      lastSyncedAt: DateTime.now(),
      clearError: true,
    );
    _retainedMapResourceBytes = status.completedResourceSize;
    await _persist();
    if (previousId != null && previousId != candidateId) {
      try {
        await deleteOfflineRegion(previousId);
      } catch (error) {
        debugPrint('[OFFLINE MAP] Old region cleanup deferred: $error');
      }
    }
  }

  Future<void> _failPendingDownload(int? candidateId, String message) async {
    if (candidateId != null && candidateId != state.regionId) {
      try {
        await deleteOfflineRegion(candidateId);
      } catch (error) {
        debugPrint('[OFFLINE MAP] Invalid candidate cleanup deferred: $error');
      }
    }
    state = state.copyWith(
      phase: OfflinePackagePhase.failed,
      clearPendingRegion: true,
      mapResourceBytes: _retainedMapResourceBytes,
      error: message,
    );
    await _persist();
  }

  Future<void> pause() async {
    final id = state.pendingRegionId ?? state.regionId;
    if (!supportsNativeMapResources || id == null) return;
    await pauseOfflineRegionDownload(id);
    state = state.copyWith(phase: OfflinePackagePhase.paused);
  }

  Future<void> resume() async {
    final id = state.pendingRegionId ?? state.regionId;
    if (!supportsNativeMapResources || id == null) {
      await downloadOrUpdate();
      return;
    }
    await resumeOfflineRegionDownload(id);
    state = state.copyWith(
      phase: OfflinePackagePhase.downloadingMap,
      clearError: true,
    );
    _monitorRegion(id);
  }

  Future<void> _monitorRegion(int id) async {
    if (_monitoredRegionId == id) return;
    _monitoredRegionId = id;
    try {
      while (mounted &&
          _monitoredRegionId == id &&
          state.phase == OfflinePackagePhase.downloadingMap) {
        await Future<void>.delayed(const Duration(seconds: 1));
        if (!mounted || state.phase != OfflinePackagePhase.downloadingMap) {
          break;
        }
        final status = await getOfflineRegionStatus(id);
        state = state.copyWith(
          mapProgress: status.downloadProgress,
          mapResourceBytes: status.completedResourceSize,
        );
        if (status.isComplete) {
          state = state.copyWith(phase: OfflinePackagePhase.validating);
          await _validateAndPromote(id);
          break;
        }
      }
    } catch (error) {
      debugPrint('[OFFLINE MAP] Resume monitor failed: $error');
      await _failPendingDownload(id, 'offline_error_interrupted');
    } finally {
      if (_monitoredRegionId == id) _monitoredRegionId = null;
    }
  }

  Future<void> deletePackage() async {
    if (state.isBusy) return;
    state = state.copyWith(phase: OfflinePackagePhase.deleting);
    try {
      if (supportsNativeMapResources && state.regionId != null) {
        await deleteOfflineRegion(state.regionId!);
      }
      if (supportsNativeMapResources &&
          state.pendingRegionId != null &&
          state.pendingRegionId != state.regionId) {
        await deleteOfflineRegion(state.pendingRegionId!);
      }
      if (supportsNativeMapResources) await clearAmbientCache();
      final storage = LocalStorageService.instance;
      await storage.remove(_metadataKey);
      final auth = _ref.read(authProvider);
      await storage.remove(PrivateSessionDataService.mapCacheKey(
        isLoggedIn: auth.isLoggedIn,
        role: auth.role.name,
        userId: auth.userId,
      ));
      await storage.remove('smart_map_cache_tourist');
      await storage.remove('smart_map_cache_guest');
      await storage.remove('smart_map_categories_cache');
      state = const OfflineMapState();
      _ref.invalidate(mapMarkersProvider);
      _ref.invalidate(mapPlaceCategoriesProvider);
    } catch (error) {
      state = state.copyWith(
        phase: OfflinePackagePhase.failed,
        error: 'offline_error_delete',
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
