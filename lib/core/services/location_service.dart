import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';

/// Result of a location fetch.
sealed class LocationResult {}

final class LocationSuccess extends LocationResult {
  LocationSuccess(this.position);
  final Position position;
}

final class LocationDenied extends LocationResult {
  LocationDenied(this.message);
  final String message;
}

final class LocationError extends LocationResult {
  LocationError(this.message);
  final String message;
}

/// GPS location service with permission handling and fallback to Tubigon center.
class LocationService {
  /// Request permission and return current position.
  Future<LocationResult> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return LocationDenied('Location services are disabled. Please enable GPS.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return LocationDenied('Location permission denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return LocationDenied(
        'Location permission permanently denied. Please enable it in Settings.',
      );
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      return LocationSuccess(position);
    } catch (e) {
      debugPrint('LocationService error: $e');
      return LocationError('Failed to get location. Please try again.');
    }
  }

  /// Stream of position updates.
  Stream<Position> get positionStream => Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      );

  /// Calculate distance in meters between two coordinates.
  double distanceBetween(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }

  /// Distance from a position to a target in kilometers.
  double distanceToKm(Position from, double targetLat, double targetLng) {
    return distanceBetween(
          from.latitude,
          from.longitude,
          targetLat,
          targetLng,
        ) /
        1000;
  }

  /// Returns the Tubigon municipality center as a fallback position.
  Position get tubigonCenter => Position(
        latitude: AppConstants.tubigonLat,
        longitude: AppConstants.tubigonLng,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        heading: 0,
        speed: 0,
        speedAccuracy: 0,
        altitudeAccuracy: 0,
        headingAccuracy: 0,
      );
}

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

final currentLocationProvider = FutureProvider<LocationResult>((ref) async {
  return ref.watch(locationServiceProvider).getCurrentLocation();
});
