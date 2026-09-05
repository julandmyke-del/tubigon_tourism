import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:tubigon_tourism/features/map/providers/map_provider.dart';

class _FakeLocationGateway implements LocationGateway {
  final currentPositionCompleter = Completer<Position>();
  final positions = StreamController<Position>.broadcast();
  int streamListenCount = 0;
  int streamCancelCount = 0;

  @override
  Future<bool> isServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<LocationPermission> requestPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<Position> currentPosition() => currentPositionCompleter.future;

  @override
  Stream<Position> positionStream() =>
      positions.stream.map<Position>((position) => position).asBroadcastStream(
            onListen: (_) => streamListenCount++,
            onCancel: (_) => streamCancelCount++,
          );
}

Position _position(double latitude, double longitude) => Position(
      latitude: latitude,
      longitude: longitude,
      timestamp: DateTime(2026),
      accuracy: 1,
      altitude: 0,
      heading: 0,
      speed: 0,
      speedAccuracy: 0,
      altitudeAccuracy: 0,
      headingAccuracy: 0,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('stopping during a pending GPS request rejects the late result',
      () async {
    final gateway = _FakeLocationGateway();
    final notifier = UserLocationNotifier(gateway);

    final pending = notifier.locate(track: true);
    await Future<void>.delayed(Duration.zero);
    notifier.stopTracking();
    gateway.currentPositionCompleter.complete(_position(9.95, 123.96));

    expect(await pending, isFalse);
    expect(notifier.current.isLoading, isFalse);
    expect(notifier.current.isTracking, isFalse);
    expect(gateway.streamListenCount, 0);
    notifier.dispose();
    await gateway.positions.close();
  });

  test('live GPS stream is cancelled and late positions are ignored', () async {
    final gateway = _FakeLocationGateway();
    gateway.currentPositionCompleter.complete(_position(9.95, 123.96));
    final notifier = UserLocationNotifier(gateway);

    expect(await notifier.locate(track: true), isTrue);
    expect(gateway.streamListenCount, 1);
    gateway.positions.add(_position(9.951, 123.961));
    await Future<void>.delayed(Duration.zero);
    expect(notifier.current.latitude, 9.951);

    notifier.stopTracking();
    await Future<void>.delayed(Duration.zero);
    final stoppedLatitude = notifier.current.latitude;
    gateway.positions.add(_position(9.97, 123.98));
    await Future<void>.delayed(Duration.zero);

    expect(gateway.streamCancelCount, 1);
    expect(notifier.current.isTracking, isFalse);
    expect(notifier.current.latitude, stoppedLatitude);
    notifier.dispose();
    await gateway.positions.close();
  });
}
