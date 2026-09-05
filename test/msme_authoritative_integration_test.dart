import 'package:flutter_test/flutter_test.dart';
import 'package:tubigon_tourism/features/map/providers/map_provider.dart';
import 'package:tubigon_tourism/features/msmepage/models/msme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('MSME cache round-trip preserves authoritative and null coordinates',
      () {
    final bazak = Msme.fromJson({
      'id': '35555555-5555-4555-8555-555555555555',
      'integer_id': 41,
      'name': 'BAZAK Food Park',
      'category': 'Food & Dining',
      'tagline': 'Food Park / Restaurant',
      'latitude': 9.9499662,
      'longitude': 123.9664321,
      'is_verified': true,
    });
    final purpleYam = Msme.fromJson({
      'id': '36666666-6666-4666-8666-666666666666',
      'integer_id': 42,
      'name': 'Purple Yam - Tubigon',
      'category': 'Food & Dining',
      'tagline': 'Cake Shop / Bakery',
      'latitude': null,
      'longitude': null,
      'is_verified': true,
    });

    final cachedBazak = Msme.fromJson(bazak.toJson());
    final cachedPurpleYam = Msme.fromJson(purpleYam.toJson());
    expect(cachedBazak.uuid, bazak.uuid);
    expect(cachedBazak.latitude, 9.9499662);
    expect(cachedBazak.longitude, 123.9664321);
    expect(cachedPurpleYam.uuid, purpleYam.uuid);
    expect(cachedPurpleYam.latitude, isNull);
    expect(cachedPurpleYam.longitude, isNull);
  });

  test('BAZAK map marker keeps its authoritative MSME identity and coordinates',
      () {
    final marker = MapMarker.fromJson({
      'id': 'msme:35555555-5555-4555-8555-555555555555',
      'source_id': '35555555-5555-4555-8555-555555555555',
      'source_integer_id': 41,
      'type': 'msme',
      'name': 'BAZAK Food Park',
      'category': 'Food & Dining',
      'latitude': 9.9499662,
      'longitude': 123.9664321,
      'is_verified': true,
    });
    final restored = MapMarker.fromJson(marker.toJson());

    expect(restored.id, 'msme:35555555-5555-4555-8555-555555555555');
    expect(restored.sourceId, '35555555-5555-4555-8555-555555555555');
    expect(restored.sourceIntegerId, 41);
    expect(restored.latitude, 9.9499662);
    expect(restored.longitude, 123.9664321);
    expect(restored.favoriteType, 'msme');
    expect(restored.itineraryEntityType, 'msme');
    expect(restored.itineraryEntityId, restored.sourceId);
    expect(restored.hasCoordinates, isTrue);
  });
}
