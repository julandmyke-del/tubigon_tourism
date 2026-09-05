import 'package:flutter_test/flutter_test.dart';
import 'package:tubigon_tourism/features/itinerary/models/itinerary.dart';
import 'package:tubigon_tourism/features/map/providers/map_provider.dart';

void main() {
  test('itinerary JSON keeps reservations and sorts each day by stop order',
      () {
    final itinerary = Itinerary.fromJson({
      'id': 'trip-1',
      'name': 'Tubigon Day Trip',
      'start_date': '2026-09-01',
      'end_date': '2026-09-02',
      'day_count': 2,
      'status': 'upcoming',
      'items': [
        _item('second', 1, 2),
        _item('another-day', 2, 1),
        _item('first', 1, 1, reservation: true),
      ],
    });

    expect(itinerary.status, ItineraryStatus.upcoming);
    expect(itinerary.itemsForDay(1).map((item) => item.id),
        orderedEquals(['first', 'second']));
    expect(itinerary.itemsForDay(1).first.plannedStartTime, '09:30');
    expect(itinerary.itemsForDay(1).first.reservation?.status, 'confirmed');

    final cached = Itinerary.fromJson(itinerary.toJson());
    expect(cached.items.length, 3);
    expect(cached.itemsForDay(2).single.place?.name, 'Place another-day');
  });

  test('eligible map markers map to the backend itinerary entity types', () {
    final marker = MapMarker.fromJson({
      'id': 'tourist-spot:abc',
      'source_id': 'abc',
      'type': 'tourist_spot',
      'name': 'Heritage Walk',
      'latitude': 9.95,
      'longitude': 123.96,
    });

    expect(marker.isItineraryEligible, isTrue);
    expect(marker.itineraryEntityType, 'tourist_spot');
    expect(marker.itineraryEntityId, 'abc');

    final emergency = MapMarker.fromJson({
      'id': 'emergency:1',
      'source_id': '1',
      'type': 'emergency',
      'name': 'Emergency',
      'latitude': 9.95,
      'longitude': 123.96,
    });
    expect(emergency.isItineraryEligible, isFalse);
  });

  test('itinerary places preserve authoritative detail and booking links', () {
    final touristSpot = ItineraryPlace.fromJson({
      'entity_type': 'tourist_spot',
      'entity_id': 'spot-uuid',
      'source_integer_id': 12,
      'marker_id': 'tourist_spot:spot-uuid',
      'name': 'Mangrove Forest Batasan',
      'category': 'Eco Tourism',
      'latitude': null,
      'longitude': null,
      'is_bookable': true,
      'booking_enabled': true,
    });
    final msme = ItineraryPlace.fromJson({
      'entity_type': 'msme',
      'entity_id': 'msme-uuid',
      'source_integer_id': 8,
      'marker_id': 'msme:msme-uuid',
      'name': 'BAZAK Food Park',
      'category': 'Food & Dining',
    });

    expect(touristSpot.hasCoordinates, isFalse);
    expect(touristSpot.detailPath, '/explore/spot/12');
    expect(touristSpot.bookingPath, '/reservations/create?spot=spot-uuid');
    expect(msme.hasCoordinates, isFalse);
    expect(msme.detailPath, '/explore/msme/8');
    expect(
        ItineraryPlace.fromJson(msme.toJson()).detailPath, '/explore/msme/8');
  });
}

Map<String, dynamic> _item(String id, int day, int order,
        {bool reservation = false}) =>
    {
      'id': id,
      'itinerary_id': 'trip-1',
      'entity_type': 'map_location',
      'entity_id': 'place-$id',
      'day_number': day,
      'sort_order': order,
      'planned_start_time': '09:30:00',
      'visit_status': 'planned',
      'place': {
        'entity_type': 'map_location',
        'entity_id': 'place-$id',
        'marker_id': 'map-location:$id',
        'name': 'Place $id',
        'category': 'Important Place',
        'latitude': '9.95',
        'longitude': '123.96',
      },
      if (reservation)
        'reservation': {
          'id': 'reservation-1',
          'date': '2026-09-01',
          'status': 'confirmed',
        },
    };
