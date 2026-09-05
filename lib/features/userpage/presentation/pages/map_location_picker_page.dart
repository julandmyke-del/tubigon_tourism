import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/location/tubigon_boundary.dart';

class MapLocationPickerPage extends StatefulWidget {
  const MapLocationPickerPage({
    super.key,
    this.initialLatitude = AppConstants.tubigonLat,
    this.initialLongitude = AppConstants.tubigonLng,
    this.title = 'Pin Waste Report Location',
    this.instruction =
        'Tap the map or drag the orange pin to the exact report location within Tubigon.',
    this.allowPortServiceArea = false,
  });

  final double initialLatitude;
  final double initialLongitude;
  final String title;
  final String instruction;
  final bool allowPortServiceArea;

  @override
  State<MapLocationPickerPage> createState() => _MapLocationPickerPageState();
}

class _MapLocationPickerPageState extends State<MapLocationPickerPage> {
  late LatLng _selected;
  MapLibreMapController? _mapController;
  Circle? _locationMarker;
  TubigonBoundary? _boundary;
  final List<Line> _boundaryLines = [];
  bool _styleLoaded = false;
  bool _tileError = false;
  Timer? _styleLoadTimer;

  @override
  void initState() {
    super.initState();
    _selected = LatLng(widget.initialLatitude, widget.initialLongitude);
  }

  @override
  void dispose() {
    _styleLoadTimer?.cancel();
    _styleLoaded = false;
    final controller = _mapController;
    _mapController = null;
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        title: Text(widget.title),
      ),
      body: Stack(children: [
        MapLibreMap(
          initialCameraPosition: CameraPosition(target: _selected, zoom: 17),
          styleString: AppConstants.mapStyleUrl,
          compassEnabled: false,
          logoEnabled: false,
          attributionButtonPosition: AttributionButtonPosition.bottomLeft,
          rotateGesturesEnabled: true,
          tiltGesturesEnabled: false,
          onMapCreated: _onMapCreated,
          onStyleLoadedCallback: () => unawaited(_onStyleLoaded()),
          onMapClick: (_, point) => unawaited(_moveMarker(point)),
        ),
        Positioned(
          left: 16,
          right: 16,
          top: 16,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withValues(alpha: .94),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Text(
              widget.instruction,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        if (_tileError)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withValues(alpha: .96),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Row(children: [
                const Expanded(
                  child: Text('Map tiles unavailable. Check your connection.',
                      style: TextStyle(color: Colors.white, fontSize: 12)),
                ),
                TextButton(onPressed: _retryStyle, child: const Text('Retry')),
              ]),
            ),
          ),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: Colors.black,
              minimumSize: const Size.fromHeight(50),
            ),
            onPressed: _confirmLocation,
            icon: const Icon(Icons.check_circle_rounded),
            label: const Text('Confirm This Location'),
          ),
        ),
      ),
    );
  }

  void _onMapCreated(MapLibreMapController controller) {
    if (!mounted) {
      controller.dispose();
      return;
    }
    _mapController = controller;
    _styleLoadTimer?.cancel();
    _styleLoadTimer = Timer(const Duration(seconds: 15), () {
      if (mounted && !_styleLoaded) setState(() => _tileError = true);
    });
  }

  Future<void> _onStyleLoaded() async {
    if (!mounted) return;
    final controller = _mapController;
    if (controller == null) return;
    _styleLoaded = true;
    _locationMarker = null;
    _boundaryLines.clear();
    _styleLoadTimer?.cancel();
    if (mounted) setState(() => _tileError = false);
    final boundary = await TubigonBoundary.load();
    if (!mounted || !identical(controller, _mapController)) return;
    _boundary = boundary;
    for (final ring in boundary.outerRings) {
      if (!mounted || !identical(controller, _mapController)) return;
      _boundaryLines.add(await controller.addLine(LineOptions(
        geometry: ring
            .map((point) => LatLng(point.latitude, point.longitude))
            .toList(growable: false),
        lineColor: '#F59E0B',
        lineWidth: 3,
        lineOpacity: .9,
      )));
    }
    if (!_isAllowed(boundary, _selected)) {
      _selected = const LatLng(
        AppConstants.tubigonLat,
        AppConstants.tubigonLng,
      );
      await controller.animateCamera(CameraUpdate.newLatLng(_selected));
      if (mounted) {
        _showScopeMessage(
            'Your starting location is outside Tubigon. The pin was reset to Tubigon.');
      }
    }
    if (!mounted || !identical(controller, _mapController)) return;
    _locationMarker = await controller.addCircle(CircleOptions(
      geometry: _selected,
      circleRadius: 11,
      circleColor: '#F59E0B',
      circleStrokeColor: '#FFFFFF',
      circleStrokeWidth: 4,
      draggable: true,
    ));
  }

  Future<void> _moveMarker(LatLng point) async {
    final boundary = _boundary ?? await TubigonBoundary.load();
    if (!mounted) return;
    if (!_isAllowed(boundary, point)) {
      _showScopeMessage(
          'Locations must be inside the Municipality of Tubigon, Bohol.');
      return;
    }
    setState(() => _selected = point);
    final controller = _mapController;
    final marker = _locationMarker;
    if (controller != null && marker != null) {
      await controller.updateCircle(marker, CircleOptions(geometry: point));
    }
  }

  Future<void> _retryStyle() async {
    if (!mounted) return;
    final controller = _mapController;
    if (controller == null) return;
    _styleLoaded = false;
    setState(() => _tileError = false);
    _styleLoadTimer?.cancel();
    _styleLoadTimer = Timer(const Duration(seconds: 15), () {
      if (mounted && !_styleLoaded) setState(() => _tileError = true);
    });
    await controller.setStyle(AppConstants.mapStyleUrl);
  }

  void _confirmLocation() {
    final controller = _mapController;
    final marker = _locationMarker;
    if (controller != null && marker != null) {
      _selected = controller.getCircleLatLng(marker);
    }
    final boundary = _boundary;
    if (boundary == null || !_isAllowed(boundary, _selected)) {
      _showScopeMessage(
          'Move the pin inside the orange Tubigon municipal boundary before confirming.');
      return;
    }
    context.pop({
      'latitude': _selected.latitude,
      'longitude': _selected.longitude,
    });
  }

  bool _isAllowed(TubigonBoundary boundary, LatLng point) =>
      boundary.contains(
        latitude: point.latitude,
        longitude: point.longitude,
      ) ||
      (widget.allowPortServiceArea &&
          boundary.containsPortServiceArea(
            latitude: point.latitude,
            longitude: point.longitude,
          ));

  void _showScopeMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF9A3412),
    ));
  }
}
