import 'package:flutter_test/flutter_test.dart';
import 'package:tubigon_tourism/core/location/tubigon_boundary.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('accepts the Tubigon municipal center', () async {
    final boundary = await TubigonBoundary.load();

    expect(
      boundary.contains(latitude: 9.9515287, longitude: 123.9618897),
      isTrue,
    );
  });

  test('accepts a Tubigon municipal island polygon', () async {
    final boundary = await TubigonBoundary.load();

    expect(
      boundary.contains(latitude: 9.9840, longitude: 123.9945),
      isTrue,
    );
  });

  test('rejects coordinates outside Tubigon', () async {
    final boundary = await TubigonBoundary.load();

    expect(
      boundary.contains(latitude: 9.6500, longitude: 123.8500),
      isFalse,
    );
  });

  test('recognizes only the narrow passenger-port service area', () async {
    final boundary = await TubigonBoundary.load();

    expect(
      boundary.contains(latitude: 9.95636, longitude: 123.95778),
      isFalse,
    );
    expect(
      boundary.containsPortServiceArea(latitude: 9.95636, longitude: 123.95778),
      isTrue,
    );
    expect(
      boundary.containsPortServiceArea(latitude: 9.9500, longitude: 123.95778),
      isFalse,
    );
  });
}
