import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tubigon_tourism/core/services/local_storage_service.dart';
import 'package:tubigon_tourism/core/services/private_session_data_service.dart';
import 'package:tubigon_tourism/core/network/api_client.dart';
import 'package:tubigon_tourism/core/utils/auth_action_guard.dart';
import 'package:tubigon_tourism/features/favorites/repositories/favorites_repository.dart';
import 'package:tubigon_tourism/features/authentication/auth_provider.dart';
import 'package:tubigon_tourism/features/offline_maps/offline_map_provider.dart';
import 'package:tubigon_tourism/features/connected_operations/data/connected_operations_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('safe Tourist return routes', () {
    test('keeps internal booking destinations and their query', () {
      expect(
        safeTouristReturnRoute('/reservations/create?spot=abc'),
        '/reservations/create?spot=abc',
      );
    });

    test('rejects external and privileged destinations', () {
      expect(safeTouristReturnRoute('https://evil.example'), isNull);
      expect(safeTouristReturnRoute('//evil.example/path'), isNull);
      expect(safeTouristReturnRoute('/admin/users'), isNull);
      expect(safeTouristReturnRoute('/auth/login'), isNull);
    });
  });

  test('favorite entity types normalize to one canonical key', () {
    expect(FavoritesRepository.normalizeType('tourist_spot'), 'spot');
    expect(
      const FavoriteKey('spot', 'place-id'),
      FavoriteKey(
        FavoritesRepository.normalizeType('touristSpot'),
        'place-id',
      ),
    );
  });

  test('persisted privileged role is not authenticated while restoring', () {
    const restoringAdmin = AuthState(
      isLoggedIn: true,
      isRestoring: true,
      role: UserRole.admin,
      name: 'Stored Admin',
    );

    expect(restoringAdmin.isAuthenticated, isFalse);
    expect(restoringAdmin.homeRoute, '/admin');
  });

  test('offline package metadata uses measured values', () {
    final downloaded = DateTime.utc(2026, 8, 27, 1, 2);
    final state = OfflineMapState(
      phase: OfflinePackagePhase.ready,
      dataReady: true,
      baseMapReady: true,
      regionId: 7,
      mapResourceVersion: 'style-v2',
      downloadedAt: downloaded,
      lastSyncedAt: downloaded,
      placeCount: 42,
      placeDataBytes: 2048,
      mapResourceBytes: 4096,
    );
    final restored = OfflineMapState.fromJson(state.toJson());
    expect(restored.placeCount, 42);
    expect(restored.totalBytes, 6144);
    expect(restored.downloadedAt, downloaded);
    expect(restored.canOpen, isTrue);
    expect(restored.mapResourceVersion, 'style-v2');
  });

  test('place snapshots alone are never presented as a complete offline map',
      () {
    const dataOnly = OfflineMapState(
      phase: OfflinePackagePhase.ready,
      dataReady: true,
      baseMapReady: false,
    );
    expect(dataOnly.hasDataSnapshot, isTrue);
    expect(dataOnly.canOpen, isFalse);
  });

  test('private map caches are isolated by role and user', () {
    expect(
      PrivateSessionDataService.mapCacheKey(
        isLoggedIn: true,
        role: UserRole.lguStaff.name,
        userId: 'lgu-a',
      ),
      isNot(PrivateSessionDataService.mapCacheKey(
        isLoggedIn: true,
        role: UserRole.lguStaff.name,
        userId: 'lgu-b',
      )),
    );
    expect(
      PrivateSessionDataService.mapCacheKey(
        isLoggedIn: true,
        role: UserRole.tourist.name,
        userId: 'tourist-a',
      ),
      PrivateSessionDataService.mapCacheKey(
        isLoggedIn: false,
        role: UserRole.guest.name,
      ),
    );
  });

  test('logout cleanup preserves public offline map data', () async {
    SharedPreferences.setMockInitialValues({
      'smart_map_cache_public': 'public places',
      'smart_map_categories_cache': 'categories',
      'smart_map_cache_private_lguStaff_lgu-a': 'private places',
      'itineraries_cache_lgu-a': 'private itinerary',
      'itinerary_pending_sync_lgu-a': 'pending mutation',
    });
    await LocalStorageService.init();

    await PrivateSessionDataService.clear(
      userId: 'lgu-a',
      role: UserRole.lguStaff.name,
      clearLocalDatabase: false,
    );

    final storage = LocalStorageService.instance;
    expect(storage.getString('smart_map_cache_public'), 'public places');
    expect(storage.getString('smart_map_categories_cache'), 'categories');
    expect(
        storage.containsKey('smart_map_cache_private_lguStaff_lgu-a'), isFalse);
    expect(storage.containsKey('itineraries_cache_lgu-a'), isFalse);
    expect(storage.containsKey('itinerary_pending_sync_lgu-a'), isFalse);
  });

  test('concern drafts persist locally and can be cleared after submission',
      () async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorageService.init();
    final repository = ConnectedOperationsRepository(ApiClient(Dio()));

    await repository.saveConcernDraft({
      'category_id': 'category-1',
      'subject': 'Saved support request',
      'description': 'This remains on the device until it is submitted.',
      'priority': 'normal',
    });

    expect(repository.loadConcernDraft()?['subject'], 'Saved support request');
    await repository.clearConcernDraft();
    expect(repository.loadConcernDraft(), isNull);
  });
}
