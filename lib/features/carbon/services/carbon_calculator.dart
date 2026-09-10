enum TravelMode {
  walking('Walking', 0),
  bicycle('Bicycle', 0),
  motorcycle('Motorcycle', 0.113),
  tricycle('Motorized tricycle', 0.120),
  privateCar('Private car', 0.170),
  van('Van', 0.105),
  bus('Bus', 0.102),
  ferry('Ferry (foot passenger)', 0.019);

  const TravelMode(this.label, this.kgCo2ePerPassengerKm);
  final String label;
  final double kgCo2ePerPassengerKm;
}

enum TripType {
  oneWay('One way', 1),
  roundTrip('Round trip', 2);

  const TripType(this.label, this.distanceMultiplier);
  final String label;
  final int distanceMultiplier;
}

class CarbonEstimate {
  const CarbonEstimate({
    required this.kgCo2e,
    required this.comparableCarKgCo2e,
    required this.mode,
    required this.distanceKm,
    required this.travelers,
    required this.tripType,
  });

  final double kgCo2e;
  final double comparableCarKgCo2e;
  final TravelMode mode;
  final double distanceKm;
  final int travelers;
  final TripType tripType;

  double get differenceFromCarKg => comparableCarKgCo2e - kgCo2e;
}

/// A simple educational estimate, not a trip inventory or scientific model.
///
/// Factors are rounded operational proxies in kg CO2e per passenger-km. Bus,
/// motorcycle, car, van, and foot-passenger ferry values are adapted from the
/// UK Government 2026 GHG conversion-factor methodology. The motorized
/// tricycle factor is explicitly a local proxy because no authoritative
/// Tubigon fleet factor is available. Walking/bicycle are zero only for direct
/// trip emissions; food, vehicle manufacture, and infrastructure are excluded.
/// Source: https://www.gov.uk/government/publications/greenhouse-gas-reporting-conversion-factors-2026
abstract final class CarbonCalculator {
  static CarbonEstimate estimate({
    required TravelMode mode,
    required double distanceKm,
    required int travelers,
    required TripType tripType,
  }) {
    if (!distanceKm.isFinite || distanceKm <= 0 || distanceKm > 5000) {
      throw ArgumentError.value(distanceKm, 'distanceKm', 'Use 0–5,000 km.');
    }
    if (travelers < 1 || travelers > 100) {
      throw ArgumentError.value(travelers, 'travelers', 'Use 1–100 travelers.');
    }
    final passengerKm = distanceKm * travelers * tripType.distanceMultiplier;
    return CarbonEstimate(
      kgCo2e: passengerKm * mode.kgCo2ePerPassengerKm,
      comparableCarKgCo2e:
          passengerKm * TravelMode.privateCar.kgCo2ePerPassengerKm,
      mode: mode,
      distanceKm: distanceKm,
      travelers: travelers,
      tripType: tripType,
    );
  }
}
