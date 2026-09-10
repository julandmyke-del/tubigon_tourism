import 'package:flutter_test/flutter_test.dart';
import 'package:tubigon_tourism/features/carbon/services/carbon_calculator.dart';

void main() {
  group('CarbonCalculator', () {
    test('calculates passenger-kilometers and round-trip multiplier', () {
      final result = CarbonCalculator.estimate(
        mode: TravelMode.bus,
        distanceKm: 10,
        travelers: 2,
        tripType: TripType.roundTrip,
      );
      expect(result.kgCo2e, closeTo(4.08, 0.0001));
      expect(result.comparableCarKgCo2e, closeTo(6.8, 0.0001));
    });

    test('walking excludes direct trip emissions', () {
      final result = CarbonCalculator.estimate(
        mode: TravelMode.walking,
        distanceKm: 3,
        travelers: 1,
        tripType: TripType.oneWay,
      );
      expect(result.kgCo2e, 0);
    });

    test('rejects invalid input instead of fabricating a result', () {
      expect(
        () => CarbonCalculator.estimate(
          mode: TravelMode.ferry,
          distanceKm: 0,
          travelers: 1,
          tripType: TripType.oneWay,
        ),
        throwsArgumentError,
      );
    });
  });
}
