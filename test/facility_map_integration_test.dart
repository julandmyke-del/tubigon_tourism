import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubigon_tourism/features/map/providers/map_provider.dart';

MapMarker marker({
  required String name,
  required String slug,
  required List<String> keys,
  String? contact,
}) =>
    MapMarker.fromJson({
      'id': 'map_location:$slug',
      'source_id': slug,
      'map_location_id': slug,
      'type': 'map_location',
      'name': name,
      'description': '$name facility in Tubigon',
      'address': 'Tubigon, Bohol',
      'latitude': 9.95,
      'longitude': 123.96,
      'category': slug == 'emergency' ? 'Emergency' : 'Port / Transport',
      'category_slug': slug,
      'category_keys': keys,
      'category_icon':
          slug == 'emergency' ? 'local_hospital' : 'directions_boat',
      'contact': contact,
      'is_verified': true,
    });

void main() {
  test('facility marker actions follow verification-aware category policy', () {
    final hospital = marker(
      name: 'Tubigon Community Hospital',
      slug: 'emergency',
      keys: const ['emergency'],
      contact: '0947-249-6029',
    );
    final hiddenPhone = marker(
      name: 'BFP Tubigon Fire Station',
      slug: 'emergency',
      keys: const ['emergency'],
    );
    final port = marker(
      name: 'Tubigon Port',
      slug: 'port-transport',
      keys: const ['port-transport'],
    );

    expect(hospital.hasCallableContact, isTrue);
    expect(hospital.isItineraryEligible, isFalse);
    expect(hiddenPhone.hasCallableContact, isFalse);
    expect(port.hasFerrySchedules, isTrue);
    expect(port.isItineraryEligible, isTrue);
  });

  test('multi-category filters and facility search include managed places',
      () async {
    final markers = [
      marker(
        name: 'Tubigon Community Hospital',
        slug: 'emergency',
        keys: const ['emergency'],
      ),
      marker(
        name: 'Tubigon Port',
        slug: 'port-transport',
        keys: const ['port-transport'],
      ),
    ];
    final container = ProviderContainer(overrides: [
      mapMarkersProvider.overrideWith((ref) async => markers),
    ]);
    addTearDown(container.dispose);
    await container.read(mapMarkersProvider.future);

    container.read(mapFilterProvider.notifier).state = const MapFilterState(
      activeCategoryKeys: {'emergency', 'port-transport'},
    );
    expect(
        container.read(filteredMapMarkersProvider).requireValue, hasLength(2));

    container.read(mapFilterProvider.notifier).state = const MapFilterState(
      searchQuery: 'hospital',
    );
    expect(
      container.read(filteredMapMarkersProvider).requireValue.single.name,
      'Tubigon Community Hospital',
    );
  });
}
