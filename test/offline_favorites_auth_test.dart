import 'package:flutter_test/flutter_test.dart';
import 'package:tubigon_tourism/core/utils/auth_action_guard.dart';
import 'package:tubigon_tourism/features/favorites/repositories/favorites_repository.dart';
import 'package:tubigon_tourism/features/offline_maps/offline_map_provider.dart';

void main() {
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

  test('offline package metadata uses measured values', () {
    final downloaded = DateTime.utc(2026, 8, 27, 1, 2);
    final state = OfflineMapState(
      phase: OfflinePackagePhase.ready,
      dataReady: true,
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
  });
}
