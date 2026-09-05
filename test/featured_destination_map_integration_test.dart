import 'package:flutter_test/flutter_test.dart';
import 'package:tubigon_tourism/core/location/tubigon_boundary.dart';
import 'package:tubigon_tourism/features/itinerary/models/itinerary.dart';
import 'package:tubigon_tourism/features/map/providers/map_provider.dart';
import 'package:tubigon_tourism/features/map/services/directions_service.dart';
import 'package:tubigon_tourism/features/tourist_spots/models/tourist_spot.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('tourist spot cache round-trip preserves authoritative coordinates', () {
    final spot = TouristSpot.fromJson({
      'id': 'e0eb5c7a-4e1e-54c1-9501-9aea355ecbcb',
      'integer_id': 7,
      'name': 'Enchanted Ilijan Hill Volcanic Nature Park',
      'slug': 'enchanted-ilijan-hill',
      'latitude': 9.91339,
      'longitude': 123.94232,
      'is_active': true,
      'is_published': true,
      'is_featured': true,
      'is_bookable': false,
      'booking_enabled': false,
    });

    final cached = TouristSpot.fromJson(spot.toJson());

    expect(cached.uuid, spot.uuid);
    expect(cached.latitude, 9.91339);
    expect(cached.longitude, 123.94232);
    expect(cached.hasCoordinates, isTrue);
    expect(cached.canAcceptBookings, isFalse);
  });

  test('missing and malformed coordinates are safely unavailable', () {
    final missing = TouristSpot.fromJson({
      'id': 'missing-coordinate-spot',
      'name': 'Mundong Sandbar',
    });
    final itineraryPlace = ItineraryPlace.fromJson({
      'entity_type': 'tourist_spot',
      'entity_id': 'missing-coordinate-spot',
      'marker_id': 'tourist_spot:missing-coordinate-spot',
      'name': 'Mundong Sandbar',
      'category': 'Island / Beach',
    });
    final invalidMarker = MapMarker.fromJson({
      'id': 'tourist_spot:invalid',
      'source_id': 'invalid',
      'type': 'tourist_spot',
      'name': 'Invalid destination',
      'latitude': 91,
      'longitude': 181,
    });

    expect(missing.hasCoordinates, isFalse);
    expect(itineraryPlace.hasCoordinates, isFalse);
    expect(invalidMarker.hasCoordinates, isFalse);
    expect(invalidMarker.isItineraryEligible, isFalse);
  });

  test('preapproved marine marker keeps its tourist spot ID and map scope',
      () async {
    final marker = MapMarker.fromJson({
      'id': 'tourist_spot:fb3e498f-91fd-58bf-8c7a-e57ee429ab48',
      'source_id': 'fb3e498f-91fd-58bf-8c7a-e57ee429ab48',
      'source_integer_id': 2,
      'type': 'tourist_spot',
      'name': 'Dumog Sandbar',
      'latitude': 9.98820,
      'longitude': 123.87830,
      'is_preapproved': true,
      'is_active': true,
      'is_published': true,
    });
    final restored = MapMarker.fromJson(marker.toJson());
    final boundary = await TubigonBoundary.load();

    expect(boundary.contains(latitude: 9.98820, longitude: 123.87830), isFalse);
    expect(restored.isWithinMapScope(boundary), isTrue);
    expect(restored.sourceId, 'fb3e498f-91fd-58bf-8c7a-e57ee429ab48');
    expect(restored.itineraryEntityId, restored.sourceId);
    expect(restored.favoriteType, 'spot');
    expect(restored.isItineraryEligible, isTrue);
  });

  test('directions reject invalid destination coordinates before routing',
      () async {
    await expectLater(
      DirectionsService().route(
        origin: const MapCoordinate(9.9515, 123.9618),
        destination: const MapCoordinate(0, 0),
      ),
      throwsArgumentError,
    );
  });
}
