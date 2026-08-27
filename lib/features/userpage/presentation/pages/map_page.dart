import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/location/tubigon_boundary.dart';
import '../../../../core/network/connectivity_provider.dart';
import '../../../../core/services/local_storage_service.dart';
import '../../../../core/utils/auth_action_guard.dart';
import '../../../authentication/auth_provider.dart';
import '../../../favorites/repositories/favorites_repository.dart';
import '../../../itinerary/models/itinerary.dart';
import '../../../itinerary/presentation/itinerary_add_sheet.dart';
import '../../../itinerary/repositories/itinerary_repository.dart';
import '../../../map/providers/map_provider.dart';
import '../../../map/place_category_style.dart';
import '../../../map/services/directions_service.dart';
import '../../../map/services/route_cache_service.dart';
import '../../../offline_maps/offline_map_provider.dart';

class MapPage extends ConsumerStatefulWidget {
  const MapPage({
    super.key,
    this.initialMarkerId,
    this.startNavigation = false,
    this.itineraryId,
    this.itineraryDay = 1,
    this.offlineMode = false,
  });

  final String? initialMarkerId;
  final bool startNavigation;
  final String? itineraryId;
  final int itineraryDay;
  final bool offlineMode;

  @override
  ConsumerState<MapPage> createState() => _MapPageState();
}

class _MapPageState extends ConsumerState<MapPage> {
  static const _tubigon =
      LatLng(AppConstants.tubigonLat, AppConstants.tubigonLng);
  static final Map<String, Future<Uint8List>> _markerImageCache = {};
  final _searchController = TextEditingController();
  MapLibreMapController? _mapController;
  List<LatLng> _routePoints = const [];
  final Map<Symbol, MapMarker> _markerSymbols = {};
  final Map<Symbol, MapMarker> _labelSymbols = {};
  final Map<String, Symbol> _markerSymbolsById = {};
  final Map<String, Symbol> _labelSymbolsById = {};
  final Map<String, bool> _labelVisibility = {};
  Symbol? _selectedSymbol;
  Circle? _userLocationCircle;
  Symbol? _userLocationLabel;
  Line? _routeLine;
  final List<Line> _boundaryLines = [];
  final Set<String> _installedMarkerImages = {};
  List<MapMarker>? _pendingMarkerSync;
  bool _syncingMarkers = false;
  bool _styleLoaded = false;
  bool _tileError = false;
  bool _routeLoading = false;
  Map<String, int> _itineraryStopNumbers = const {};
  String? _itineraryFingerprint;
  double? _itineraryDistanceKm;
  int? _itineraryEtaMinutes;
  bool _favoriteLoading = false;
  bool _hasCenteredOnUser = false;
  bool _showPlaceLabels = true;
  bool _searchResultsExpanded = false;
  bool _initialMarkerUnavailableShown = false;
  String? _pendingSelectionId;
  String? _renderedMarkerFingerprint;
  Timer? _searchDebounce;
  Timer? _styleLoadTimer;

  @override
  void initState() {
    super.initState();
    if (widget.offlineMode) {
      Future.microtask(() {
        if (!mounted) return;
        ref.read(offlineMapModeProvider.notifier).state = true;
        if (OfflineMapNotifier.supportsNativeMapResources) {
          unawaited(setOffline(true));
        }
      });
    }
    final filter = ref.read(mapFilterProvider);
    _showPlaceLabels = LocalStorageService.instance
            .getBool(AppConstants.mapLabelsVisibleKey) ??
        true;
    if (widget.initialMarkerId != null) {
      // A direct destination must not be hidden by search/category state from
      // an earlier ordinary map session.
      _pendingSelectionId = widget.initialMarkerId;
      Future.microtask(() {
        if (!mounted) return;
        ref.read(mapFilterProvider.notifier).state = filter.copyWith(
          searchQuery: '',
          activeCategoryKeys: const <String>{},
        );
      });
    } else {
      _searchController.text = filter.searchQuery;
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _styleLoadTimer?.cancel();
    ref.read(userLocationProvider.notifier).stopTracking();
    ref.read(selectedMarkerProvider.notifier).state = null;
    ref.read(navigationProvider.notifier).state = const NavigationState();
    if (widget.offlineMode) {
      ref.read(offlineMapModeProvider.notifier).state = false;
      if (!kIsWeb && OfflineMapNotifier.supportsNativeMapResources) {
        unawaited(setOffline(false));
      }
    }
    _mapController?.dispose();
    super.dispose();
  }

  bool get _canNavigate {
    final role = ref.read(authProvider).role;
    return role == UserRole.tourist || role == UserRole.guest;
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final locations = ref.watch(filteredMapMarkersProvider);
    final allLocations =
        ref.watch(mapMarkersProvider).valueOrNull ?? const <MapMarker>[];
    final selected = ref.watch(selectedMarkerProvider);
    final userLocation = ref.watch(userLocationProvider);
    final navigation = ref.watch(navigationProvider);
    final connectivity = ref.watch(connectivityProvider);
    final favoriteKeys =
        ref.watch(favoriteKeysProvider).valueOrNull ?? const <FavoriteKey>{};
    final isOffline = widget.offlineMode ||
        connectivity.valueOrNull == ConnectivityStatus.offline;
    final searchQuery = ref.watch(mapFilterProvider).searchQuery.trim();
    final itinerary = widget.itineraryId == null
        ? null
        : ref.watch(itineraryDetailProvider(widget.itineraryId!)).valueOrNull;

    if (itinerary != null) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _syncItineraryRoute(itinerary));
    }

    ref.listen<AsyncValue<List<MapMarker>>>(filteredMapMarkersProvider,
        (_, next) {
      next.whenData(_queueMarkerSync);
    });

    ref.listen<UserLocationState>(userLocationProvider, (previous, next) {
      if (!next.hasLocation) return;
      unawaited(_syncUserLocation(next));
      if (!_hasCenteredOnUser) {
        _hasCenteredOnUser = true;
        unawaited(_centerOnUser(next));
      }
      final nav = ref.read(navigationProvider);
      if (nav.isNavigating && nav.destination != null) {
        final remaining =
            nav.destination!.distanceTo(next.latitude!, next.longitude!);
        ref.read(navigationProvider.notifier).state = nav.copyWith(
          distanceKm: remaining,
          etaMinutes: math.max(1, (remaining / 30 * 60).ceil()),
          isNavigating: remaining >= 0.05,
        );
        if (remaining < 0.05) {
          ref.read(userLocationProvider.notifier).stopTracking();
          if (mounted) {
            _showMessage('You have arrived at ${nav.destination!.name}.');
          }
        }
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF080F1A),
      body: Stack(
        children: [
          locations.when(
            data: (items) => MapLibreMap(
              initialCameraPosition:
                  const CameraPosition(target: _tubigon, zoom: 14),
              styleString: AppConstants.mapStyleUrl,
              compassEnabled: false,
              logoEnabled: false,
              attributionButtonPosition: AttributionButtonPosition.bottomLeft,
              attributionButtonMargins: const math.Point<double>(12, 92),
              rotateGesturesEnabled: true,
              tiltGesturesEnabled: false,
              trackCameraPosition: true,
              onMapCreated: (controller) => _onMapCreated(controller, items),
              onStyleLoadedCallback: () => unawaited(_onStyleLoaded()),
              onCameraIdle: () => unawaited(_refreshLabelVisibility()),
              onMapClick: (_, __) => unawaited(_clearSelectedMarker()),
            ),
            loading: () => const Center(
              child: CircularProgressIndicator(color: Color(0xFFF59E0B)),
            ),
            error: (error, _) => _MapError(
              message: 'Map locations are unavailable. Please try again.',
              onRetry: () => ref.invalidate(mapMarkersProvider),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                if (isOffline) _OfflinePill(explicit: widget.offlineMode),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Row(
                    children: [
                      if (auth.role != UserRole.tourist &&
                          auth.role != UserRole.guest)
                        _RoundControl(
                          tooltip: 'Return to dashboard',
                          icon: Icons.arrow_back_rounded,
                          onPressed: () => context.go(auth.homeRoute),
                        ),
                      if (auth.role != UserRole.tourist &&
                          auth.role != UserRole.guest)
                        const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          height: 50,
                          decoration: _glassDecoration(radius: 18),
                          child: TextField(
                            controller: _searchController,
                            onChanged: _onSearchChanged,
                            onTap: () =>
                                setState(() => _searchResultsExpanded = true),
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Search within Tubigon, Bohol',
                              hintStyle:
                                  const TextStyle(color: Color(0xFF94A3B8)),
                              prefixIcon: const Icon(Icons.search_rounded,
                                  color: Color(0xFFF59E0B)),
                              suffixIcon: _searchController.text.isEmpty
                                  ? null
                                  : IconButton(
                                      onPressed: _clearSearch,
                                      icon: const Icon(Icons.close_rounded,
                                          color: Color(0xFF94A3B8)),
                                    ),
                              border: InputBorder.none,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                _CategoryBar(
                  role: auth.role,
                  active: ref.watch(mapFilterProvider).activeCategoryKeys,
                  onSelected: (categoryKey) {
                    final current = ref.read(mapFilterProvider);
                    final next = Set<String>.of(current.activeCategoryKeys);
                    if (categoryKey == null) {
                      next.clear();
                    } else if (!next.add(categoryKey)) {
                      next.remove(categoryKey);
                    }
                    ref.read(mapFilterProvider.notifier).state =
                        current.copyWith(activeCategoryKeys: next);
                  },
                ),
                if (_searchResultsExpanded &&
                    _searchController.text.trim().isNotEmpty)
                  _MapSearchResults(
                    results: _matchingSearchResults(allLocations),
                    onSelected: _selectSearchResult,
                  ),
              ],
            ),
          ),
          Positioned(
            right: 12,
            bottom:
                selected == null ? (navigation.isNavigating ? 128 : 24) : 238,
            child: Column(
              children: [
                _RoundControl(
                  tooltip: 'Zoom in',
                  icon: Icons.add_rounded,
                  onPressed: () =>
                      _mapController?.animateCamera(CameraUpdate.zoomIn()),
                ),
                const SizedBox(height: 8),
                _RoundControl(
                  tooltip: 'Zoom out',
                  icon: Icons.remove_rounded,
                  onPressed: () =>
                      _mapController?.animateCamera(CameraUpdate.zoomOut()),
                ),
                const SizedBox(height: 8),
                _RoundControl(
                  tooltip: 'Recenter on Tubigon',
                  icon: Icons.location_city_rounded,
                  onPressed: _recenterTubigon,
                ),
                const SizedBox(height: 8),
                _RoundControl(
                  tooltip: userLocation.isTracking
                      ? 'Stop GPS tracking'
                      : 'Current location',
                  icon: userLocation.isLoading
                      ? Icons.hourglass_top_rounded
                      : userLocation.isTracking
                          ? Icons.location_disabled_rounded
                          : Icons.my_location_rounded,
                  active: userLocation.isTracking,
                  onPressed: userLocation.isLoading ? null : _toggleLocation,
                ),
                const SizedBox(height: 8),
                _RoundControl(
                  tooltip: _showPlaceLabels
                      ? 'Hide place labels'
                      : 'Show place labels',
                  icon: _showPlaceLabels
                      ? Icons.label_rounded
                      : Icons.label_off_rounded,
                  active: _showPlaceLabels,
                  onPressed: () {
                    setState(() => _showPlaceLabels = !_showPlaceLabels);
                    unawaited(LocalStorageService.instance.setBool(
                      AppConstants.mapLabelsVisibleKey,
                      value: _showPlaceLabels,
                    ));
                    unawaited(_refreshLabelVisibility(force: true));
                  },
                ),
                if (auth.role == UserRole.lguStaff ||
                    auth.role == UserRole.admin) ...[
                  const SizedBox(height: 8),
                  _RoundControl(
                    tooltip: 'Waste report monitoring',
                    icon: Icons.delete_sweep_rounded,
                    onPressed: () => context.push(auth.role == UserRole.admin
                        ? '/admin/waste-reports'
                        : '/lgu/waste-reports'),
                  ),
                ],
              ],
            ),
          ),
          if (userLocation.error != null)
            Positioned(
              left: 12,
              right: 72,
              bottom: selected == null ? 18 : 232,
              child: _LocationError(
                message: userLocation.error!,
                onSettings: () => Geolocator.openAppSettings(),
              ),
            ),
          Positioned(
            left: 12,
            bottom:
                selected == null ? (navigation.isNavigating ? 108 : 10) : 220,
            child: const _MapAttribution(),
          ),
          if (_tileError)
            Positioned(
              left: 12,
              right: 72,
              top: 168,
              child: _TileErrorPill(onRetry: _retryMapStyle),
            ),
          if (!_tileError && userLocation.isWithinTubigon == false)
            const Positioned(
              left: 12,
              right: 72,
              top: 168,
              child: _ScopeNotice(
                icon: Icons.wrong_location_rounded,
                message:
                    'You are currently outside Tubigon. The map will only show and save Tubigon locations.',
              ),
            ),
          if (!_tileError &&
              userLocation.isWithinTubigon != false &&
              searchQuery.isEmpty &&
              (locations.valueOrNull?.isEmpty ?? false))
            const Positioned(
              left: 12,
              right: 72,
              top: 168,
              child: _ScopeNotice(
                icon: Icons.location_off_rounded,
                message: 'No published locations are available yet. '
                    'The Tubigon base map remains available.',
              ),
            ),
          if (!_tileError &&
              userLocation.isWithinTubigon != false &&
              searchQuery.isNotEmpty &&
              (locations.valueOrNull?.isEmpty ?? false))
            const Positioned(
              left: 12,
              right: 72,
              top: 168,
              child: _ScopeNotice(
                icon: Icons.travel_explore_rounded,
                message:
                    'No Tubigon location matches this search. Locations outside Tubigon are not included.',
              ),
            ),
          if (navigation.isNavigating && selected == null)
            Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: _NavigationCard(
                  navigation: navigation,
                  onStop: _stopNavigation,
                )),
          if (selected != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: _LocationCard(
                marker: selected,
                userLocation: userLocation,
                canNavigate: _canNavigate,
                canFavorite: (auth.role == UserRole.tourist ||
                        auth.role == UserRole.guest) &&
                    selected.isFavoritable,
                isFavorite: favoriteKeys.contains(
                  FavoriteKey(selected.favoriteType, selected.sourceId),
                ),
                routeLoading: _routeLoading,
                favoriteLoading: _favoriteLoading,
                onClose: () => unawaited(_clearSelectedMarker()),
                onDirections:
                    _routeLoading ? null : () => _getDirections(selected),
                onFavorite:
                    _favoriteLoading ? null : () => _toggleFavorite(selected),
                onDetails: () => _openDetails(selected),
                onAddToItinerary: selected.isItineraryEligible &&
                        (auth.role == UserRole.tourist ||
                            auth.role == UserRole.guest)
                    ? () => showAddToItinerarySheet(context, ref, selected)
                    : null,
                onCall: selected.category == MapMarkerCategory.emergency &&
                        (selected.contact?.trim().isNotEmpty ?? false)
                    ? () => _callMarker(selected)
                    : null,
                onFerry: selected.categorySlug == 'port-transport'
                    ? () => context.push('/ferry')
                    : null,
              ),
            ),
          if (itinerary != null)
            Positioned(
              left: 12,
              right: 12,
              top: 166,
              child: _ItineraryMapBanner(
                itinerary: itinerary,
                day: widget.itineraryDay,
                distanceKm: _itineraryDistanceKm,
                etaMinutes: _itineraryEtaMinutes,
                onBack: () => context.pop(),
              ),
            ),
        ],
      ),
    );
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    setState(() => _searchResultsExpanded = value.trim().isNotEmpty);
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final current = ref.read(mapFilterProvider);
      ref.read(mapFilterProvider.notifier).state =
          current.copyWith(searchQuery: value);
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    final current = ref.read(mapFilterProvider);
    ref.read(mapFilterProvider.notifier).state =
        current.copyWith(searchQuery: '');
    setState(() => _searchResultsExpanded = false);
  }

  List<MapMarker> _matchingSearchResults(List<MapMarker> markers) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return const [];
    final matches = markers.where((item) =>
        item.name.toLowerCase().contains(query) ||
        item.description.toLowerCase().contains(query) ||
        (item.address?.toLowerCase().contains(query) ?? false) ||
        (item.categoryName?.toLowerCase().contains(query) ?? false));
    final sorted = matches.toList()
      ..sort((a, b) {
        final featured = (b.isFeatured ? 1 : 0).compareTo(a.isFeatured ? 1 : 0);
        return featured != 0 ? featured : a.name.compareTo(b.name);
      });
    return sorted.take(6).toList(growable: false);
  }

  Future<void> _selectSearchResult(MapMarker marker) async {
    FocusScope.of(context).unfocus();
    setState(() => _searchResultsExpanded = false);
    _searchDebounce?.cancel();

    final current = ref.read(mapFilterProvider);
    final categories = Set<String>.of(current.activeCategoryKeys);
    final hiddenByCategory =
        categories.isNotEmpty && !marker.categoryKeys.any(categories.contains);
    if (hiddenByCategory) categories.add(marker.categorySlug);
    final query = _searchController.text.trim();
    final needsMarkerSync = hiddenByCategory || current.searchQuery != query;
    if (needsMarkerSync) {
      _pendingSelectionId = marker.id;
      ref.read(mapFilterProvider.notifier).state = current.copyWith(
        searchQuery: query,
        activeCategoryKeys: categories,
      );
      return;
    }

    final symbol = _markerSymbolsById[marker.id];
    if (symbol != null) await _onSymbolTapped(symbol);
  }

  void _onMapCreated(MapLibreMapController controller, List<MapMarker> items) {
    _mapController = controller;
    controller.onSymbolTapped.add(_onSymbolTapped);
    _pendingMarkerSync = List<MapMarker>.of(items);
    _styleLoadTimer?.cancel();
    _styleLoadTimer = Timer(const Duration(seconds: 15), () {
      if (mounted && !_styleLoaded) setState(() => _tileError = true);
    });
  }

  Future<void> _onStyleLoaded() async {
    final controller = _mapController;
    if (controller == null) return;

    _styleLoadTimer?.cancel();
    _styleLoaded = true;
    _markerSymbols.clear();
    _labelSymbols.clear();
    _markerSymbolsById.clear();
    _labelSymbolsById.clear();
    _labelVisibility.clear();
    _renderedMarkerFingerprint = null;
    _selectedSymbol = null;
    _userLocationCircle = null;
    _userLocationLabel = null;
    _routeLine = null;
    _boundaryLines.clear();
    _installedMarkerImages.clear();
    if (mounted) setState(() => _tileError = false);

    try {
      await controller.setSymbolIconAllowOverlap(true);
      await controller.setSymbolIconIgnorePlacement(true);
      await controller.setSymbolTextAllowOverlap(false);
      await controller.setSymbolTextIgnorePlacement(false);
      await _drawTubigonBoundary(controller);
      final selected = ref.read(selectedMarkerProvider);
      if (selected != null) _pendingSelectionId = selected.id;
      final queued = _pendingMarkerSync ??
          ref.read(filteredMapMarkersProvider).valueOrNull ??
          const <MapMarker>[];
      _queueMarkerSync(queued);
      await _syncUserLocation(ref.read(userLocationProvider));
      await _syncRouteLine();
    } catch (_) {
      if (mounted) setState(() => _tileError = true);
    }
  }

  Future<void> _ensureMarkerImages(
      MapLibreMapController controller, List<MapMarker> markers) async {
    for (final marker in markers) {
      final imageId = _markerImageId(marker);
      if (!_installedMarkerImages.add(imageId)) continue;
      final image = _markerImageCache.putIfAbsent(
        imageId,
        () => _createMarkerImage(
          color: _markerColor(marker),
          icon: placeCategoryIcon(marker.categoryIcon,
              fallback: _categoryIcon(marker.category)),
        ),
      );
      await controller.addImage(
        imageId,
        await image,
      );
    }
  }

  Future<void> _drawTubigonBoundary(MapLibreMapController controller) async {
    final boundary = await TubigonBoundary.load();
    for (final ring in boundary.outerRings) {
      _boundaryLines.add(await controller.addLine(LineOptions(
        geometry: ring
            .map((point) => LatLng(point.latitude, point.longitude))
            .toList(growable: false),
        lineColor: '#F59E0B',
        lineWidth: 2.5,
        lineOpacity: .88,
      )));
    }
  }

  Future<Uint8List> _createMarkerImage({
    required Color color,
    required IconData icon,
  }) async {
    const size = 96.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: .30)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 5);
    final fillPaint = Paint()..color = color;
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;
    const center = Offset(size / 2, 39);

    final tip = Path()
      ..moveTo(34, 62)
      ..lineTo(48, 88)
      ..lineTo(62, 62)
      ..close();
    canvas.drawPath(tip.shift(const Offset(0, 3)), shadowPaint);
    canvas.drawCircle(center + const Offset(0, 3), 31, shadowPaint);
    canvas.drawPath(tip, fillPaint);
    canvas.drawCircle(center, 31, fillPaint);
    canvas.drawCircle(center, 31, borderPaint);

    final painter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          color: Colors.white,
          fontSize: 34,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
        canvas, center - Offset(painter.width / 2, painter.height / 2));

    final image =
        await recorder.endRecording().toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) throw StateError('Could not create map marker image.');
    return bytes.buffer.asUint8List();
  }

  void _queueMarkerSync(List<MapMarker> items) {
    _pendingMarkerSync = List<MapMarker>.of(items);
    if (!_styleLoaded || _syncingMarkers) return;
    unawaited(_drainMarkerSync());
  }

  Future<void> _drainMarkerSync() async {
    _syncingMarkers = true;
    try {
      while (_styleLoaded && _pendingMarkerSync != null) {
        final items = _pendingMarkerSync!;
        _pendingMarkerSync = null;
        await _replaceMarkerSymbols(items);
      }
    } catch (_) {
      if (mounted) setState(() => _tileError = true);
    } finally {
      _syncingMarkers = false;
    }
  }

  Future<void> _replaceMarkerSymbols(List<MapMarker> items) async {
    final controller = _mapController;
    if (controller == null || !_styleLoaded) return;
    final fingerprint = items
        .map((item) => '${item.id}:${item.latitude}:${item.longitude}:'
            '${item.name}:${item.categoryIcon}:${item.markerColor}:'
            '${item.isFeatured}')
        .join('|');
    if (_renderedMarkerFingerprint == fingerprint) {
      await _selectPendingMarker();
      return;
    }
    _renderedMarkerFingerprint = fingerprint;
    if (_markerSymbols.isNotEmpty) {
      await controller
          .removeSymbols(_markerSymbols.keys.toList(growable: false));
    }
    if (_labelSymbols.isNotEmpty) {
      await controller
          .removeSymbols(_labelSymbols.keys.toList(growable: false));
    }
    _markerSymbols.clear();
    _labelSymbols.clear();
    _markerSymbolsById.clear();
    _labelSymbolsById.clear();
    _labelVisibility.clear();
    _selectedSymbol = null;
    final selected = ref.read(selectedMarkerProvider);
    if (selected != null && !items.any((item) => item.id == selected.id)) {
      ref.read(selectedMarkerProvider.notifier).state = null;
    }
    if (items.isEmpty) return;
    await _ensureMarkerImages(controller, items);

    final markerSymbols = await controller.addSymbols(
      items
          .map((item) => SymbolOptions(
                geometry: LatLng(item.latitude, item.longitude),
                iconImage: _markerImageId(item),
                iconSize: .62,
                iconAnchor: 'bottom',
                zIndex: _markerZIndex(item),
              ))
          .toList(growable: false),
      items
          .map((item) => <String, dynamic>{'markerId': item.id})
          .toList(growable: false),
    );
    for (var index = 0; index < markerSymbols.length; index++) {
      final symbol = markerSymbols[index];
      final marker = items[index];
      _markerSymbols[symbol] = marker;
      _markerSymbolsById[marker.id] = symbol;
    }

    final zoom = controller.cameraPosition?.zoom ?? 14;
    final labelSymbols = await controller.addSymbols(
      items.map((item) {
        final visible = _labelShouldShow(item, zoom);
        _labelVisibility[item.id] = visible;
        return _labelOptions(item, visible: visible);
      }).toList(growable: false),
      items
          .map((item) => <String, dynamic>{
                'markerId': item.id,
                'annotationType': 'placeLabel',
              })
          .toList(growable: false),
    );
    for (var index = 0; index < labelSymbols.length; index++) {
      final symbol = labelSymbols[index];
      final marker = items[index];
      _labelSymbols[symbol] = marker;
      _labelSymbolsById[marker.id] = symbol;
    }

    await _selectPendingMarker();
  }

  Future<void> _onSymbolTapped(Symbol symbol) async {
    final marker = _markerSymbols[symbol] ?? _labelSymbols[symbol];
    if (marker == null) return;
    final controller = _mapController;
    if (controller == null) return;
    if (_selectedSymbol != null &&
        _markerSymbols.containsKey(_selectedSymbol)) {
      final previous = _markerSymbols[_selectedSymbol!]!;
      await controller.updateSymbol(_selectedSymbol!,
          SymbolOptions(iconSize: .62, zIndex: _markerZIndex(previous)));
      final previousLabel = _labelSymbolsById[previous.id];
      if (previousLabel != null) {
        final zoom = controller.cameraPosition?.zoom ?? 14;
        final visible = _labelShouldShow(previous, zoom);
        _labelVisibility[previous.id] = visible;
        await controller.updateSymbol(
            previousLabel, _labelOptions(previous, visible: visible));
      }
    }
    final markerSymbol = _markerSymbolsById[marker.id];
    if (markerSymbol == null) return;
    _selectedSymbol = markerSymbol;
    await controller.updateSymbol(
        markerSymbol, const SymbolOptions(iconSize: .78, zIndex: 20));
    final label = _labelSymbolsById[marker.id];
    if (label != null) {
      _labelVisibility[marker.id] = _showPlaceLabels;
      await controller.updateSymbol(
        label,
        _labelOptions(marker,
            visible: _showPlaceLabels, selected: _showPlaceLabels),
      );
    }
    ref.read(selectedMarkerProvider.notifier).state = marker;
    await controller.animateCamera(
      CameraUpdate.newLatLng(LatLng(marker.latitude, marker.longitude)),
    );
  }

  Future<void> _clearSelectedMarker() async {
    final controller = _mapController;
    final symbol = _selectedSymbol;
    _selectedSymbol = null;
    ref.read(selectedMarkerProvider.notifier).state = null;
    if (controller != null &&
        symbol != null &&
        _markerSymbols.containsKey(symbol)) {
      final marker = _markerSymbols[symbol]!;
      await controller.updateSymbol(
          symbol, SymbolOptions(iconSize: .62, zIndex: _markerZIndex(marker)));
      final label = _labelSymbolsById[marker.id];
      if (label != null) {
        final zoom = controller.cameraPosition?.zoom ?? 14;
        final visible = _labelShouldShow(marker, zoom);
        _labelVisibility[marker.id] = visible;
        await controller.updateSymbol(
            label, _labelOptions(marker, visible: visible));
      }
    }
  }

  int _markerZIndex(MapMarker marker) {
    if (marker.category == MapMarkerCategory.emergency) return 6;
    if (marker.isFeatured) return 5;
    return 2;
  }

  int _labelZIndex(MapMarker marker) {
    if (marker.category == MapMarkerCategory.emergency) return -8;
    if (marker.isFeatured) return -7;
    if (marker.categorySlug == 'port-transport') return -6;
    return 0;
  }

  SymbolOptions _labelOptions(
    MapMarker marker, {
    required bool visible,
    bool selected = false,
  }) {
    final emergency = marker.category == MapMarkerCategory.emergency;
    return SymbolOptions(
      geometry: LatLng(marker.latitude, marker.longitude),
      textField: visible
          ? '${_itineraryStopNumbers[marker.id] == null ? '' : '${_itineraryStopNumbers[marker.id]}. '}${marker.name}'
          : '',
      textSize: selected ? 15 : 12,
      textMaxWidth: 14,
      textColor: selected
          ? '#FBBF24'
          : emergency
              ? '#FECACA'
              : '#F8FAFC',
      textHaloColor: '#0F172A',
      textHaloWidth: selected ? 3 : 2,
      textHaloBlur: 1,
      textOffset: Offset(0, selected ? -3.2 : -2.8),
      textAnchor: 'bottom',
      zIndex: selected ? -12 : _labelZIndex(marker),
    );
  }

  bool _labelShouldShow(MapMarker marker, double zoom) {
    if (!_showPlaceLabels) return false;
    if (ref.read(selectedMarkerProvider)?.id == marker.id) return true;

    final user = ref.read(userLocationProvider);
    if (user.hasLocation &&
        marker.distanceTo(user.latitude!, user.longitude!) < .08) {
      return false;
    }

    if (zoom >= 15.5) return true;
    if (zoom >= 13.5) {
      return marker.isFeatured ||
          marker.category == MapMarkerCategory.touristSpot ||
          marker.category == MapMarkerCategory.emergency ||
          const {
            'shopping',
            'accommodation',
            'port-transport',
            'government',
            'banks-services',
          }.contains(marker.categorySlug);
    }
    if (zoom >= 11.5) {
      return marker.isFeatured ||
          marker.category == MapMarkerCategory.emergency ||
          marker.categorySlug == 'port-transport';
    }
    return marker.isFeatured;
  }

  Future<void> _refreshLabelVisibility({bool force = false}) async {
    final controller = _mapController;
    if (controller == null || !_styleLoaded || _syncingMarkers) return;
    final zoom = controller.cameraPosition?.zoom ?? 14;
    final selectedId = ref.read(selectedMarkerProvider)?.id;
    for (final entry in _labelSymbols.entries) {
      final marker = entry.value;
      final visible = _labelShouldShow(marker, zoom);
      if (!force && _labelVisibility[marker.id] == visible) continue;
      _labelVisibility[marker.id] = visible;
      await controller.updateSymbol(
        entry.key,
        _labelOptions(
          marker,
          visible: visible,
          selected: visible && selectedId == marker.id,
        ),
      );
    }
  }

  Future<void> _selectPendingMarker() async {
    final targetId = _pendingSelectionId;
    if (targetId == null) return;
    for (final entry in _markerSymbols.entries) {
      if (entry.value.id != targetId &&
          entry.value.sourceId != targetId &&
          entry.value.name.toLowerCase() != targetId.toLowerCase()) {
        continue;
      }
      _pendingSelectionId = null;
      final isInitialTarget = targetId == widget.initialMarkerId;
      await _onSymbolTapped(entry.key);
      if (isInitialTarget && widget.startNavigation) {
        await _getDirections(entry.value);
      }
      return;
    }
    final filter = ref.read(mapFilterProvider);
    if (!_initialMarkerUnavailableShown &&
        targetId == widget.initialMarkerId &&
        filter.searchQuery.isEmpty &&
        filter.activeCategoryKeys.isEmpty) {
      _initialMarkerUnavailableShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showMessage('This location is not published or is unavailable.');
        }
      });
    }
  }

  Future<void> _syncUserLocation(UserLocationState location) async {
    final controller = _mapController;
    if (controller == null || !_styleLoaded || !location.hasLocation) return;
    final point = LatLng(location.latitude!, location.longitude!);
    if (_userLocationCircle == null) {
      _userLocationCircle = await controller.addCircle(CircleOptions(
        geometry: point,
        circleRadius: 9,
        circleColor: '#2563EB',
        circleStrokeColor: '#FFFFFF',
        circleStrokeWidth: 3,
      ));
    } else {
      await controller.updateCircle(
          _userLocationCircle!, CircleOptions(geometry: point));
    }
    if (_userLocationLabel == null) {
      _userLocationLabel = await controller.addSymbol(SymbolOptions(
        geometry: point,
        textField: 'YOU ARE HERE',
        textSize: 11,
        textColor: '#0F172A',
        textHaloColor: '#FFFFFF',
        textHaloWidth: 2,
        textOffset: const Offset(0, -1.8),
        textAnchor: 'bottom',
        zIndex: -20,
      ));
    } else {
      await controller.updateSymbol(
          _userLocationLabel!, SymbolOptions(geometry: point));
    }
    await _refreshLabelVisibility();
  }

  Future<void> _syncRouteLine() async {
    final controller = _mapController;
    if (controller == null || !_styleLoaded) return;
    if (_routePoints.isEmpty) {
      if (_routeLine != null) await controller.removeLine(_routeLine!);
      _routeLine = null;
      return;
    }
    final options = LineOptions(
      geometry: _routePoints,
      lineColor: '#F59E0B',
      lineWidth: 6,
      lineOpacity: .94,
    );
    if (_routeLine == null) {
      _routeLine = await controller.addLine(options);
    } else {
      await controller.updateLine(_routeLine!, options);
    }
  }

  Future<void> _retryMapStyle() async {
    final controller = _mapController;
    if (controller == null) return;
    _styleLoaded = false;
    if (mounted) setState(() => _tileError = false);
    _styleLoadTimer?.cancel();
    _styleLoadTimer = Timer(const Duration(seconds: 15), () {
      if (mounted && !_styleLoaded) setState(() => _tileError = true);
    });
    await controller.setStyle(AppConstants.mapStyleUrl);
  }

  String _markerImageId(MapMarker marker) =>
      'tubigon-${marker.categorySlug.replaceAll(RegExp(r'[^a-z0-9-]'), '-')}';

  Color _markerColor(MapMarker marker) {
    final hex = marker.markerColor.replaceFirst('#', '');
    if (hex.length == 6) {
      final value = int.tryParse('FF$hex', radix: 16);
      if (value != null) return Color(value);
    }
    switch (marker.category) {
      case MapMarkerCategory.touristSpot:
        return const Color(0xFFF59E0B);
      case MapMarkerCategory.msme:
        return const Color(0xFF0284C7);
      case MapMarkerCategory.tourismListing:
        return const Color(0xFF7C3AED);
      case MapMarkerCategory.mapLocation:
        return const Color(0xFFF59E0B);
      case MapMarkerCategory.wasteReport:
        return const Color(0xFFDC2626);
      case MapMarkerCategory.emergency:
        return const Color(0xFFE11D48);
      case MapMarkerCategory.ecoZone:
        return const Color(0xFF16A34A);
    }
  }

  Future<void> _toggleLocation() async {
    final current = ref.read(userLocationProvider);
    if (current.isTracking) {
      ref.read(userLocationProvider.notifier).stopTracking();
      return;
    }
    final found = await ref.read(userLocationProvider.notifier).locate();
    if (found) await _centerOnUser(ref.read(userLocationProvider));
  }

  Future<void> _centerOnUser(UserLocationState location) async {
    if (!location.hasLocation) return;
    await _mapController?.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(
          target: LatLng(location.latitude!, location.longitude!), zoom: 16),
    ));
  }

  Future<void> _recenterTubigon() async {
    await _mapController?.animateCamera(CameraUpdate.newCameraPosition(
      const CameraPosition(target: _tubigon, zoom: 14),
    ));
  }

  Future<void> _getDirections(MapMarker destination) async {
    if (!_canNavigate) return;
    final boundary = await TubigonBoundary.load();
    if (!boundary.contains(
      latitude: destination.latitude,
      longitude: destination.longitude,
    )) {
      _showMessage(
          'This destination is outside Tubigon and cannot be routed from the Smart Tourism Map.');
      return;
    }
    var location = ref.read(userLocationProvider);
    if (!location.hasLocation) {
      final found = await ref.read(userLocationProvider.notifier).locate();
      if (!found) return;
      location = ref.read(userLocationProvider);
    }
    final connectivity = ref.read(connectivityProvider).valueOrNull;
    if (widget.offlineMode || connectivity == ConnectivityStatus.offline) {
      final cached =
          ref.read(routeCacheServiceProvider).latestFor(destination.id);
      if (cached == null) {
        final straightLine = destination.distanceTo(
          location.latitude!,
          location.longitude!,
        );
        _showMessage('Live road directions require an internet connection. '
            'Straight-line distance: ${straightLine < 1 ? '${(straightLine * 1000).round()} m' : '${straightLine.toStringAsFixed(1)} km'}.');
        return;
      }
      setState(() {
        _routePoints = cached.points
            .map((point) => LatLng(point.latitude, point.longitude))
            .toList(growable: false);
      });
      await _syncRouteLine();
      ref.read(navigationProvider.notifier).state = NavigationState(
        destination: destination,
        distanceKm: cached.distanceKm,
        etaMinutes: cached.durationMinutes,
      );
      await _fitRoute(_routePoints);
      _showMessage(
          'Offline cached route • ${cached.distanceKm.toStringAsFixed(1)} km '
          '• ~${cached.durationMinutes} min. Last calculated online: '
          '${cached.calculatedAt.toLocal()}.');
      return;
    }
    setState(() => _routeLoading = true);
    try {
      final origin = MapCoordinate(location.latitude!, location.longitude!);
      final destinationCoordinate =
          MapCoordinate(destination.latitude, destination.longitude);
      final result = await ref.read(directionsServiceProvider).route(
            origin: origin,
            destination: destinationCoordinate,
          );
      await ref.read(routeCacheServiceProvider).save(
            destinationId: destination.id,
            origin: origin,
            destination: destinationCoordinate,
            route: result,
          );
      if (!mounted) return;
      setState(() {
        _routePoints = result.points
            .map((point) => LatLng(point.latitude, point.longitude))
            .toList(growable: false);
      });
      await _syncRouteLine();
      ref.read(navigationProvider.notifier).state = NavigationState(
        destination: destination,
        distanceKm: result.distanceKm,
        etaMinutes: result.durationMinutes,
      );
      await _fitRoute(_routePoints);
      if (mounted) _showRouteReady(destination);
    } catch (error) {
      if (mounted) {
        _showMessage(
            'Could not calculate a road route. Check your connection and try again.');
      }
    } finally {
      if (mounted) setState(() => _routeLoading = false);
    }
  }

  void _showRouteReady(MapMarker destination) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final nav = ref.read(navigationProvider);
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(destination.name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                  'Road distance: ${nav.distanceKm?.toStringAsFixed(1)} km\nEstimated travel time: ${nav.etaMinutes} min',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFCBD5E1))),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                    child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _closeRoute();
                  },
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Close Route'),
                )),
                const SizedBox(width: 12),
                Expanded(
                    child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      foregroundColor: Colors.black),
                  onPressed: () {
                    Navigator.pop(context);
                    _startNavigation();
                  },
                  icon: const Icon(Icons.navigation_rounded),
                  label: const Text('Start Navigation'),
                )),
              ]),
            ]),
          ),
        );
      },
    );
  }

  Future<void> _startNavigation() async {
    final nav = ref.read(navigationProvider);
    if (nav.destination == null) return;
    final started =
        await ref.read(userLocationProvider.notifier).locate(track: true);
    if (!started) return;
    ref.read(navigationProvider.notifier).state =
        nav.copyWith(isNavigating: true);
    unawaited(_clearSelectedMarker());
  }

  void _closeRoute() {
    ref.read(navigationProvider.notifier).state = const NavigationState();
    setState(() => _routePoints = const []);
    unawaited(_syncRouteLine());
  }

  void _stopNavigation() {
    ref.read(userLocationProvider.notifier).stopTracking();
    ref.read(navigationProvider.notifier).state = const NavigationState();
    setState(() => _routePoints = const []);
    unawaited(_syncRouteLine());
  }

  Future<void> _syncItineraryRoute(Itinerary itinerary) async {
    final items = itinerary
        .itemsForDay(widget.itineraryDay)
        .where((item) => item.place != null)
        .toList(growable: false);
    final fingerprint = items
        .map((item) => '${item.id}:${item.sortOrder}:${item.place!.markerId}')
        .join('|');
    if (_itineraryFingerprint == fingerprint) return;
    _itineraryFingerprint = fingerprint;
    _itineraryStopNumbers = {
      for (var index = 0; index < items.length; index++)
        items[index].place!.markerId: index + 1,
    };

    ref.read(mapFilterProvider.notifier).state = const MapFilterState();
    _queueMarkerSync(ref.read(mapMarkersProvider).valueOrNull ?? const []);
    if (items.length < 2) {
      if (mounted) {
        setState(() {
          _itineraryDistanceKm = null;
          _itineraryEtaMinutes = null;
        });
      }
      return;
    }

    final points = items
        .map((item) =>
            MapCoordinate(item.place!.latitude, item.place!.longitude))
        .toList();
    final location = ref.read(userLocationProvider);
    if (itinerary.startLocationType == 'current_location' &&
        location.hasLocation) {
      points.insert(0, MapCoordinate(location.latitude!, location.longitude!));
    } else if (itinerary.startLocationType == 'custom' &&
        itinerary.startLatitude != null &&
        itinerary.startLongitude != null) {
      points.insert(0,
          MapCoordinate(itinerary.startLatitude!, itinerary.startLongitude!));
    }

    try {
      final result =
          await ref.read(directionsServiceProvider).routeThrough(points);
      if (!mounted) return;
      setState(() {
        _routePoints = result.points
            .map((point) => LatLng(point.latitude, point.longitude))
            .toList(growable: false);
        _itineraryDistanceKm = result.distanceKm;
        _itineraryEtaMinutes = result.durationMinutes;
      });
      await _syncRouteLine();
      await _fitRoute(_routePoints);
    } catch (_) {
      if (mounted) {
        _showMessage('Unable to calculate the itinerary route right now.');
      }
    }
  }

  Future<void> _fitRoute(List<LatLng> points) async {
    if (points.isEmpty) return;
    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;
    for (final point in points.skip(1)) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }
    await _mapController?.animateCamera(CameraUpdate.newLatLngBounds(
      LatLngBounds(
          southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng)),
      left: 70,
      top: 70,
      right: 70,
      bottom: 70,
    ));
  }

  Future<void> _callMarker(MapMarker marker) async {
    final phone = marker.contact?.trim();
    if (phone == null || phone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
          mounted) {
        _showMessage('Calling is not available on this device.');
      }
    } catch (_) {
      if (mounted) _showMessage('Calling is not available on this device.');
    }
  }

  Future<void> _toggleFavorite(MapMarker marker) async {
    if (!marker.isFavoritable) return;
    if (!await requireSignedIn(context, ref) || !mounted) return;
    setState(() => _favoriteLoading = true);
    try {
      await ref
          .read(favoriteKeysProvider.notifier)
          .toggle(marker.favoriteType, marker.sourceId);
      if (mounted) _showMessage('${marker.name} favorite updated.');
    } catch (error) {
      if (mounted) _showMessage('Unable to update favorites.');
    } finally {
      if (mounted) setState(() => _favoriteLoading = false);
    }
  }

  void _openDetails(MapMarker marker) {
    if (marker.category == MapMarkerCategory.mapLocation &&
        marker.mapLocationId != null) {
      context.push('/explore/place/${marker.mapLocationId}');
      return;
    }
    final id = marker.sourceIntegerId;
    if (id == null) {
      _showMessage('More details are not available for this location yet.');
      return;
    }
    if (marker.category == MapMarkerCategory.touristSpot) {
      context.push('/explore/spot/$id');
    } else if (marker.category == MapMarkerCategory.msme) {
      context.push('/explore/msme/$id');
    } else {
      _showMessage('More details are not available for this location yet.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF0F172A),
    ));
  }
}

class _MapSearchResults extends StatelessWidget {
  const _MapSearchResults({required this.results, required this.onSelected});

  final List<MapMarker> results;
  final ValueChanged<MapMarker> onSelected;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(maxHeight: 250),
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        decoration: _glassDecoration(radius: 16),
        child: results.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(14),
                child: Text(
                  'No Tubigon place matches this search.',
                  style: TextStyle(color: Color(0xFFCBD5E1)),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 6),
                shrinkWrap: true,
                itemCount: results.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: Color(0xFF334155)),
                itemBuilder: (context, index) {
                  final marker = results[index];
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      placeCategoryIcon(marker.categoryIcon,
                          fallback: _categoryIcon(marker.category)),
                      color: placeCategoryColor(marker.markerColor),
                    ),
                    title: Text(
                      marker.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      marker.address ?? marker.categoryName ?? 'Tubigon, Bohol',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFF94A3B8)),
                    ),
                    trailing: const Icon(Icons.center_focus_strong_rounded,
                        color: Color(0xFFF59E0B)),
                    onTap: () => onSelected(marker),
                  );
                },
              ),
      );
}

class _CategoryBar extends ConsumerWidget {
  const _CategoryBar(
      {required this.role, required this.active, required this.onSelected});
  final UserRole role;
  final Set<String> active;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configured = ref.watch(mapPlaceCategoriesProvider).valueOrNull ??
        const <MapPlaceCategory>[];
    final bySlug = <String, MapPlaceCategory>{
      for (final category in configured) category.slug: category,
    };
    if (bySlug.isEmpty) {
      for (final marker
          in ref.watch(mapMarkersProvider).valueOrNull ?? const <MapMarker>[]) {
        bySlug.putIfAbsent(
          marker.categorySlug,
          () => MapPlaceCategory(
            id: marker.categorySlug,
            name: marker.categoryName ?? 'Places',
            slug: marker.categorySlug,
            icon: marker.categoryIcon,
            markerColor: marker.markerColor,
            sortOrder: marker.categorySortOrder,
          ),
        );
      }
    }
    if (role == UserRole.lguStaff || role == UserRole.admin) {
      bySlug.putIfAbsent(
        'waste-reports',
        () => const MapPlaceCategory(
          id: 'waste-reports',
          name: 'Waste Reports',
          slug: 'waste-reports',
          icon: 'delete_sweep',
          markerColor: '#DC2626',
          sortOrder: 999,
        ),
      );
    }
    final categories = bySlug.values.toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return SizedBox(
      height: 40,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = index == 0 ? null : categories[index - 1];
          final selected = category == null
              ? active.isEmpty
              : active.contains(category.slug);
          return FilterChip(
            selected: selected,
            showCheckmark: selected,
            avatar: category == null
                ? null
                : Icon(placeCategoryIcon(category.icon), size: 16),
            label: Text(category?.name ?? 'All'),
            onSelected: (_) => onSelected(category?.slug),
            backgroundColor: const Color(0xFF0F172A).withValues(alpha: .92),
            selectedColor: const Color(0xFFF59E0B),
            side: BorderSide(
                color: selected
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFF334155)),
            labelStyle: TextStyle(
              color: selected ? Colors.black : const Color(0xFFE2E8F0),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          );
        },
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.marker,
    required this.userLocation,
    required this.canNavigate,
    required this.canFavorite,
    required this.isFavorite,
    required this.routeLoading,
    required this.favoriteLoading,
    required this.onClose,
    required this.onDirections,
    required this.onFavorite,
    required this.onDetails,
    required this.onAddToItinerary,
    required this.onCall,
    required this.onFerry,
  });

  final MapMarker marker;
  final UserLocationState userLocation;
  final bool canNavigate;
  final bool canFavorite;
  final bool isFavorite;
  final bool routeLoading;
  final bool favoriteLoading;
  final VoidCallback onClose;
  final VoidCallback? onDirections;
  final VoidCallback? onFavorite;
  final VoidCallback onDetails;
  final VoidCallback? onAddToItinerary;
  final VoidCallback? onCall;
  final VoidCallback? onFerry;

  @override
  Widget build(BuildContext context) {
    final distance = userLocation.hasLocation
        ? marker.distanceTo(userLocation.latitude!, userLocation.longitude!)
        : null;
    return Container(
      constraints: const BoxConstraints(maxHeight: 250),
      padding: const EdgeInsets.all(14),
      decoration: _glassDecoration(radius: 22),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            width: 78,
            height: 92,
            child: marker.images.isEmpty
                ? Container(
                    color: const Color(0xFF1E293B),
                    child: Icon(
                        placeCategoryIcon(marker.categoryIcon,
                            fallback: _categoryIcon(marker.category)),
                        color: const Color(0xFFF59E0B),
                        size: 34),
                  )
                : CachedNetworkImage(
                    imageUrl: marker.images.first,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const ColoredBox(
                      color: Color(0xFF1E293B),
                      child:
                          Icon(Icons.place_rounded, color: Color(0xFFF59E0B)),
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
              Row(children: [
                Expanded(
                    child: Text(marker.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800))),
                IconButton(
                    onPressed: onClose,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close_rounded,
                        color: Color(0xFF94A3B8), size: 20)),
              ]),
              Row(children: [
                Text(marker.categoryName ?? 'Location',
                    style: const TextStyle(
                        color: Color(0xFFF59E0B),
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
                if (marker.isVerified) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.verified_rounded,
                      size: 14, color: Color(0xFF38BDF8)),
                ],
                if (marker.isOwned) ...[
                  const SizedBox(width: 6),
                  const Text('YOUR LISTING',
                      style: TextStyle(
                          color: Color(0xFF34D399),
                          fontSize: 9,
                          fontWeight: FontWeight.w800)),
                ],
              ]),
              const SizedBox(height: 4),
              Text(
                  [marker.address, marker.description]
                      .whereType<String>()
                      .where((value) => value.trim().isNotEmpty)
                      .toSet()
                      .join(' • '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Color(0xFFCBD5E1), fontSize: 11, height: 1.3)),
              const SizedBox(height: 6),
              Wrap(spacing: 10, children: [
                if (marker.rating != null)
                  Text(
                      '★ ${marker.rating!.toStringAsFixed(1)}${marker.reviewCount == null ? '' : ' (${marker.reviewCount})'}',
                      style: const TextStyle(
                          color: Color(0xFFFBBF24), fontSize: 11)),
                if (distance != null)
                  Text(
                      distance < 1
                          ? '${(distance * 1000).round()} m away (straight-line)'
                          : '${distance.toStringAsFixed(1)} km away (straight-line)',
                      style: const TextStyle(
                          color: Color(0xFF94A3B8), fontSize: 11)),
                if (marker.status != null)
                  Text(marker.status!.replaceAll('_', ' ').toUpperCase(),
                      style: const TextStyle(
                          color: Color(0xFFFB7185),
                          fontSize: 10,
                          fontWeight: FontWeight.w700)),
                if (marker.isFeatured)
                  const Text('FEATURED',
                      style: TextStyle(
                          color: Color(0xFFF59E0B),
                          fontSize: 10,
                          fontWeight: FontWeight.w900)),
              ]),
              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 6, children: [
                if (canFavorite)
                  IconButton.filledTonal(
                    onPressed: onFavorite,
                    icon: favoriteLoading
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Icon(
                            isFavorite
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: isFavorite ? const Color(0xFFF87171) : null,
                            size: 18,
                          ),
                  ),
                if (onCall != null) ...[
                  IconButton.filledTonal(
                    tooltip: 'Call ${marker.name}',
                    onPressed: onCall,
                    icon: const Icon(Icons.call_rounded, size: 18),
                  ),
                ],
                if (onAddToItinerary != null)
                  IconButton.filledTonal(
                    tooltip: 'Add to Itinerary',
                    onPressed: onAddToItinerary,
                    icon: const Icon(Icons.playlist_add_rounded, size: 19),
                  ),
                if (onFerry != null)
                  TextButton.icon(
                    onPressed: onFerry,
                    icon: const Icon(Icons.directions_boat_rounded, size: 18),
                    label: const Text('Ferry Schedules'),
                  ),
                if (marker.category == MapMarkerCategory.touristSpot ||
                    marker.category == MapMarkerCategory.msme ||
                    marker.category == MapMarkerCategory.mapLocation) ...[
                  TextButton(
                      onPressed: onDetails, child: const Text('Details')),
                ],
                if (canNavigate) ...[
                  ElevatedButton.icon(
                    onPressed: onDirections,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF59E0B),
                        foregroundColor: Colors.black),
                    icon: routeLoading
                        ? const SizedBox.square(
                            dimension: 15,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.black))
                        : const Icon(Icons.directions_rounded, size: 18),
                    label: const Text('Directions'),
                  ),
                ],
              ]),
            ])),
      ]),
    );
  }
}

class _NavigationCard extends StatelessWidget {
  const _NavigationCard({required this.navigation, required this.onStop});
  final NavigationState navigation;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: _glassDecoration(radius: 18),
        child: Row(children: [
          const CircleAvatar(
              backgroundColor: Color(0xFFF59E0B),
              child: Icon(Icons.navigation_rounded, color: Colors.black)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                Text(navigation.destination?.name ?? 'Navigation',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w800)),
                Text(
                    '${navigation.distanceKm?.toStringAsFixed(1) ?? '--'} km • ${navigation.etaMinutes ?? '--'} min',
                    style: const TextStyle(
                        color: Color(0xFFF59E0B), fontWeight: FontWeight.w700)),
              ])),
          TextButton.icon(
              onPressed: onStop,
              icon: const Icon(Icons.stop_circle_outlined),
              label: const Text('Stop')),
        ]),
      );
}

class _ItineraryMapBanner extends StatelessWidget {
  const _ItineraryMapBanner({
    required this.itinerary,
    required this.day,
    required this.distanceKm,
    required this.etaMinutes,
    required this.onBack,
  });

  final Itinerary itinerary;
  final int day;
  final double? distanceKm;
  final int? etaMinutes;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final count = itinerary.itemsForDay(day).length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: _glassDecoration(radius: 18),
      child: Row(children: [
        IconButton(
            tooltip: 'Back to itinerary',
            visualDensity: VisualDensity.compact,
            onPressed: onBack,
            icon:
                const Icon(Icons.arrow_back_rounded, color: Color(0xFFF59E0B))),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${itinerary.name} · Day $day',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w900)),
                Text(
                    '$count stops${distanceKm == null ? '' : ' · ${distanceKm!.toStringAsFixed(1)} km · $etaMinutes min'}',
                    style: const TextStyle(
                        color: Color(0xFFCBD5E1), fontSize: 10)),
              ]),
        ),
        const Icon(Icons.route_rounded, color: Color(0xFF38BDF8)),
      ]),
    );
  }
}

class _RoundControl extends StatelessWidget {
  const _RoundControl(
      {required this.tooltip,
      required this.icon,
      required this.onPressed,
      this.active = false});
  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) => Container(
        width: 46,
        height: 46,
        decoration: _glassDecoration(radius: 16, active: active),
        child: IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          icon: Icon(icon,
              color: active ? Colors.black : const Color(0xFFF59E0B)),
        ),
      );
}

class _OfflinePill extends StatelessWidget {
  const _OfflinePill({this.explicit = false});

  final bool explicit;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: const BoxDecoration(
            color: Color(0xFFB45309),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(14))),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.offline_bolt_rounded, color: Colors.white, size: 15),
          SizedBox(width: 6),
          Text(
              explicit
                  ? 'Offline Mode • using downloaded Tubigon data'
                  : 'Offline • showing cached locations',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
        ]),
      );
}

class _LocationError extends StatelessWidget {
  const _LocationError({required this.message, required this.onSettings});
  final String message;
  final VoidCallback onSettings;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: _glassDecoration(radius: 14),
        child: Row(children: [
          const Icon(Icons.location_off_rounded,
              color: Color(0xFFFB7185), size: 18),
          const SizedBox(width: 8),
          Expanded(
              child: Text(message,
                  maxLines: 2,
                  style: const TextStyle(color: Colors.white, fontSize: 11))),
          TextButton(onPressed: onSettings, child: const Text('Settings')),
        ]),
      );
}

class _MapError extends StatelessWidget {
  const _MapError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => ColoredBox(
        color: const Color(0xFF080F1A),
        child: Center(
            child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.map_outlined, color: Color(0xFFF59E0B), size: 46),
            const SizedBox(height: 12),
            const Text('Map locations unavailable',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
            const SizedBox(height: 14),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ]),
        )),
      );
}

class _MapAttribution extends StatelessWidget {
  const _MapAttribution();

  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0xFF0F172A).withValues(alpha: .86),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () =>
              launchUrl(Uri.parse('https://www.openstreetmap.org/copyright')),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            child: Text(
              '© OpenStreetMap · OpenFreeMap',
              style: TextStyle(color: Color(0xFFE2E8F0), fontSize: 9),
            ),
          ),
        ),
      );
}

class _TileErrorPill extends StatelessWidget {
  const _TileErrorPill({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
        decoration: _glassDecoration(radius: 14),
        child: Row(children: [
          const Icon(Icons.layers_clear_rounded,
              color: Color(0xFFFBBF24), size: 18),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Map tiles are unavailable. Locations and GPS data are preserved.',
              style: TextStyle(color: Colors.white, fontSize: 11),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ]),
      );
}

class _ScopeNotice extends StatelessWidget {
  const _ScopeNotice({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(11),
        decoration: _glassDecoration(radius: 14),
        child: Row(children: [
          Icon(icon, color: const Color(0xFFFBBF24), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: const TextStyle(color: Colors.white, fontSize: 11)),
          ),
        ]),
      );
}

BoxDecoration _glassDecoration({required double radius, bool active = false}) =>
    BoxDecoration(
      color: active
          ? const Color(0xFFF59E0B)
          : const Color(0xFF0F172A).withValues(alpha: .94),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
          color: active ? const Color(0xFFF59E0B) : const Color(0xFF334155)),
      boxShadow: [
        BoxShadow(
            color: Colors.black.withValues(alpha: .35),
            blurRadius: 16,
            offset: const Offset(0, 6))
      ],
    );

IconData _categoryIcon(MapMarkerCategory category) {
  switch (category) {
    case MapMarkerCategory.touristSpot:
      return Icons.landscape_rounded;
    case MapMarkerCategory.msme:
      return Icons.storefront_rounded;
    case MapMarkerCategory.tourismListing:
      return Icons.handshake_rounded;
    case MapMarkerCategory.mapLocation:
      return Icons.place_rounded;
    case MapMarkerCategory.wasteReport:
      return Icons.delete_sweep_rounded;
    case MapMarkerCategory.emergency:
      return Icons.emergency_rounded;
    case MapMarkerCategory.ecoZone:
      return Icons.eco_rounded;
  }
}
