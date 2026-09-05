import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubigon_tourism/features/map/map_camera_policy.dart';
import 'package:tubigon_tourism/features/map/map_focus.dart';
import 'package:tubigon_tourism/features/map/providers/map_provider.dart';

const touristSpot = MapMarker(
  id: 'tourist_spot:spot-1',
  sourceId: 'spot-1',
  name: 'Mundong Sandbar',
  description: 'A nature destination',
  latitude: 9.96,
  longitude: 123.97,
  category: MapMarkerCategory.touristSpot,
  categoryName: 'Tourist Spots',
  categorySlug: 'tourist-spots',
  categoryKeys: ['tourist-spots', 'nature'],
);

const msme = MapMarker(
  id: 'msme:msme-1',
  sourceId: 'msme-1',
  name: 'BAZAK Food Park',
  description: 'Local dining and fast food choices',
  aliases: ['Baz Food Hub'],
  address: 'Tubigon, Bohol',
  latitude: 9.95,
  longitude: 123.96,
  category: MapMarkerCategory.msme,
  categoryName: 'MSMEs',
  categorySlug: 'msmes',
  categoryKeys: ['msmes', 'food-parks', 'restaurants'],
);

const invalidMarker = MapMarker(
  id: 'msme:invalid',
  sourceId: 'invalid',
  name: 'Invalid Place',
  description: 'Missing coordinates',
  latitude: 0,
  longitude: 0,
  category: MapMarkerCategory.msme,
  categorySlug: 'msmes',
  categoryKeys: ['msmes'],
);

void main() {
  late ProviderContainer container;

  setUp(() async {
    container = ProviderContainer(overrides: [
      mapMarkersProvider.overrideWith(
        (ref) async => [touristSpot, msme, invalidMarker],
      ),
    ]);
    await container.read(mapMarkersProvider.future);
  });

  tearDown(() => container.dispose());

  test('Tourist Spots and MSME filters hide non-matching markers', () {
    container.read(mapFilterProvider.notifier).state = const MapFilterState(
      activeCategoryKeys: {'tourist-spots'},
    );
    expect(
      container.read(filteredMapMarkersProvider).requireValue,
      [touristSpot],
    );

    container.read(mapFilterProvider.notifier).state = const MapFilterState(
      activeCategoryKeys: {'msmes'},
    );
    expect(container.read(filteredMapMarkersProvider).requireValue, [msme]);
  });

  test('All restores valid markers without modifying the source feed', () {
    container.read(mapFilterProvider.notifier).state = const MapFilterState(
      activeCategoryKeys: {'nature'},
    );
    container.read(mapFilterProvider.notifier).state = const MapFilterState();

    expect(
      container.read(filteredMapMarkersProvider).requireValue,
      [touristSpot, msme],
    );
    expect(container.read(mapMarkersProvider).requireValue, hasLength(3));
  });

  test('category matching accepts backend keys and category slug', () {
    expect(
      filterMapMarkers(
        [touristSpot, msme],
        const MapFilterState(activeCategoryKeys: {'food-parks'}),
      ),
      [msme],
    );
    expect(
      filterMapMarkers(
        [touristSpot, msme],
        const MapFilterState(activeCategoryKeys: {'tourist-spots'}),
      ),
      [touristSpot],
    );
  });

  test('search and category filters combine and include aliases', () {
    expect(
      filterMapMarkers(
        [touristSpot, msme],
        const MapFilterState(
          searchQuery: 'food',
          activeCategoryKeys: {'msmes'},
        ),
      ),
      [msme],
    );
    expect(
      filterMapMarkers(
        [touristSpot, msme],
        const MapFilterState(
          searchQuery: 'baz food hub',
          activeCategoryKeys: {'msmes'},
        ),
      ),
      [msme],
    );
  });

  test('offline marker values use the same local filtering rules', () {
    container.read(offlineMapModeProvider.notifier).state = true;
    container.read(mapFilterProvider.notifier).state = const MapFilterState(
      searchQuery: 'sandbar',
      activeCategoryKeys: {'nature'},
    );
    expect(
      container.read(filteredMapMarkersProvider).requireValue,
      [touristSpot],
    );
  });

  test('map focus matching uses authoritative marker and source IDs', () {
    expect(mapMarkerMatchesFocus(msme, 'msme:msme-1'), isTrue);
    expect(mapMarkerMatchesFocus(msme, 'msme-1'), isTrue);
    expect(mapMarkerMatchesFocus(msme, 'unrelated-id'), isFalse);
    expect(
      mapFocusPathForEntity(entityType: 'msme', entityId: 'msme-1'),
      '/map?marker=msme%3Amsme-1',
    );
    expect(
      mapFocusPathForMarker(msme, directions: true),
      '/map?marker=msme%3Amsme-1&navigate=true',
    );
  });

  test('camera policy keeps, centers, fits, and respects navigation', () {
    expect(
      planMapCameraForFilterChange(const [], navigationActive: false).move,
      MapCameraMove.keep,
    );
    expect(
      planMapCameraForFilterChange(
        [touristSpot],
        navigationActive: false,
      ).move,
      MapCameraMove.center,
    );
    expect(
      planMapCameraForFilterChange(
        [touristSpot, msme],
        navigationActive: false,
      ).move,
      MapCameraMove.fitBounds,
    );
    expect(
      planMapCameraForFilterChange(
        [touristSpot, msme],
        navigationActive: true,
      ).move,
      MapCameraMove.keep,
    );
  });
}
