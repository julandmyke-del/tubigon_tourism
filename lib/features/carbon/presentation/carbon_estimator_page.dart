import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/localization/app_localization.dart';
import '../../../core/network/connectivity_provider.dart';
import '../../authentication/auth_provider.dart';
import '../../map/providers/map_provider.dart';
import '../../map/services/directions_service.dart';
import '../../map/services/route_cache_service.dart';
import '../repositories/carbon_repository.dart';
import '../services/carbon_calculator.dart';

enum _DistanceMode { manual, route, itinerary }

class CarbonEstimatorPage extends ConsumerStatefulWidget {
  const CarbonEstimatorPage({
    super.key,
    this.initialDistance,
    this.initialDistanceSource,
    this.itineraryId,
    this.initialLegDistances = const [],
  });

  final double? initialDistance;
  final String? initialDistanceSource;
  final String? itineraryId;
  final List<double> initialLegDistances;

  @override
  ConsumerState<CarbonEstimatorPage> createState() =>
      _CarbonEstimatorPageState();
}

class _CarbonEstimatorPageState extends ConsumerState<CarbonEstimatorPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _distance;
  final _travelers = TextEditingController(text: '1');
  late _DistanceMode _distanceMode;
  TripType _tripType = TripType.oneWay;
  String? _factorId;
  String _originKey = 'current';
  String? _destinationId;
  String _distanceSource = 'manual';
  DateTime? _routeCalculatedAt;
  _EstimateView? _result;
  bool _routing = false;
  bool _saving = false;
  List<Map<String, dynamic>> _history = const [];
  final List<String> _legFactorIds = [];

  @override
  void initState() {
    super.initState();
    _distance = TextEditingController(
      text: widget.initialDistance?.toStringAsFixed(2) ?? '',
    );
    _distanceMode = widget.initialDistanceSource == 'itinerary'
        ? _DistanceMode.itinerary
        : _DistanceMode.manual;
    _distanceSource = widget.initialDistanceSource ?? 'manual';
    Future.microtask(_loadHistory);
  }

  @override
  void dispose() {
    _distance.dispose();
    _travelers.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final auth = ref.read(authProvider);
    if (!auth.isLoggedIn || auth.userId == null) return;
    final rows = await ref.read(carbonRepositoryProvider).history(auth.userId!);
    if (mounted) setState(() => _history = rows);
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(carbonFactorCatalogProvider);
    final markers = ref
            .watch(mapMarkersProvider)
            .valueOrNull
            ?.where((item) => item.isItineraryEligible)
            .toList(growable: false) ??
        const <MapMarker>[];
    final online = ref.watch(isOnlineProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF080F1A),
      appBar: AppBar(
        title: Text(context.tr('carbon_estimator')),
        actions: [
          IconButton(
            tooltip: 'Methodology and limitations',
            onPressed: () => _showMethodology(context, catalog.valueOrNull),
            icon: const Icon(Icons.info_outline_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _IntroCard(online: online),
          const SizedBox(height: 18),
          catalog.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => _StateCard(
              message: 'Emission factors are unavailable.',
              onPressed: () => ref.invalidate(carbonFactorCatalogProvider),
            ),
            data: (value) => _buildForm(value, markers, online),
          ),
          if (_result case final result?) ...[
            const SizedBox(height: 20),
            _ResultCard(result: result),
          ],
          if (_history.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text('My recent estimates',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            ..._history.take(5).map(_HistoryCard.new),
          ],
        ],
      ),
    );
  }

  Widget _buildForm(
      CarbonFactorCatalog catalog, List<MapMarker> markers, bool online) {
    if (_factorId == null && catalog.items.isNotEmpty) {
      _factorId = catalog.items
          .firstWhere((item) => item.mode == 'ferry_foot',
              orElse: () => catalog.items.first)
          .id;
    }
    final factor = _selectedFactor(catalog);
    final hasItineraryLegs = _distanceMode == _DistanceMode.itinerary &&
        widget.initialLegDistances.isNotEmpty;
    if (hasItineraryLegs && factor != null) {
      while (_legFactorIds.length < widget.initialLegDistances.length) {
        _legFactorIds.add(factor.id);
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (catalog.isOfflineCopy)
        _Notice(
          text:
              'Offline factor copy — cached ${DateFormat.yMMMd().add_jm().format(catalog.cachedAt.toLocal())}. Reconnect to refresh or save.',
        ),
      Form(
        key: _formKey,
        child: Column(children: [
          DropdownButtonFormField<String>(
            initialValue: _factorId,
            decoration: const InputDecoration(
              labelText: 'Travel mode *',
              prefixIcon: Icon(Icons.directions_transit_rounded),
            ),
            items: catalog.items
                .map((item) => DropdownMenuItem(
                      value: item.id,
                      child: Text(item.name),
                    ))
                .toList(growable: false),
            onChanged: (value) => setState(() {
              _factorId = value;
              if (value != null && hasItineraryLegs) {
                for (var index = 0; index < _legFactorIds.length; index++) {
                  _legFactorIds[index] = value;
                }
              }
              _result = null;
              if (_selectedFactor(catalog)?.isFerry == true &&
                  _distanceMode == _DistanceMode.route) {
                _distanceMode = _DistanceMode.manual;
                _distanceSource = 'configured_ferry';
              }
            }),
          ),
          if (factor != null) ...[
            const SizedBox(height: 5),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${factor.factor} kg CO₂e/passenger-km · ${factor.version}',
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
              ),
            ),
          ],
          const SizedBox(height: 12),
          SegmentedButton<_DistanceMode>(
            segments: const [
              ButtonSegment(value: _DistanceMode.manual, label: Text('Manual')),
              ButtonSegment(
                  value: _DistanceMode.route, label: Text('Map route')),
              ButtonSegment(
                  value: _DistanceMode.itinerary, label: Text('Itinerary')),
            ],
            selected: {_distanceMode},
            onSelectionChanged: (values) => setState(() {
              final requested = values.single;
              if (requested == _DistanceMode.route && factor?.isFerry == true) {
                _distanceMode = _DistanceMode.manual;
                _distanceSource = 'configured_ferry';
                _feedback(
                    'Ferry distance cannot use road routing. Enter a published or configured sailing distance.');
              } else {
                _distanceMode = requested;
                _distanceSource = switch (requested) {
                  _DistanceMode.manual => 'manual',
                  _DistanceMode.route => 'osrm',
                  _DistanceMode.itinerary => 'itinerary',
                };
              }
              _result = null;
            }),
          ),
          if (_distanceMode == _DistanceMode.route) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _originKey,
              decoration: const InputDecoration(labelText: 'From'),
              items: [
                const DropdownMenuItem(
                    value: 'current', child: Text('My current location')),
                ...markers.map((item) => DropdownMenuItem(
                      value: item.id,
                      child: Text(item.name, overflow: TextOverflow.ellipsis),
                    )),
              ],
              onChanged: (value) =>
                  setState(() => _originKey = value ?? 'current'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: markers.any((item) => item.id == _destinationId)
                  ? _destinationId
                  : null,
              decoration: const InputDecoration(labelText: 'To *'),
              items: markers
                  .map((item) => DropdownMenuItem(
                        value: item.id,
                        child: Text(item.name, overflow: TextOverflow.ellipsis),
                      ))
                  .toList(growable: false),
              onChanged: (value) => setState(() => _destinationId = value),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _routing
                  ? null
                  : () => _calculateRoute(markers, online: online),
              icon: _routing
                  ? const SizedBox.square(
                      dimension: 18, child: CircularProgressIndicator())
                  : const Icon(Icons.route_rounded),
              label: const Text('Calculate road route'),
            ),
          ],
          if (_distanceMode == _DistanceMode.itinerary &&
              widget.initialDistance == null) ...[
            const SizedBox(height: 12),
            const _Notice(
              text:
                  'Open one of your saved itineraries and choose “Estimate carbon” to use its calculated route distance. You may also enter a reviewed itinerary total below.',
            ),
          ],
          if (hasItineraryLegs) ...[
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Transport by itinerary leg',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 6),
            ...List.generate(widget.initialLegDistances.length, (index) {
              final available = catalog.items
                  .where((item) => !item.isFerry)
                  .toList(growable: false);
              final current =
                  available.any((item) => item.id == _legFactorIds[index])
                      ? _legFactorIds[index]
                      : available.first.id;
              _legFactorIds[index] = current;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: DropdownButtonFormField<String>(
                  initialValue: current,
                  decoration: InputDecoration(
                    labelText:
                        'Leg ${index + 1} · ${widget.initialLegDistances[index].toStringAsFixed(2)} km',
                  ),
                  items: available
                      .map((item) => DropdownMenuItem(
                            value: item.id,
                            child: Text(item.name),
                          ))
                      .toList(growable: false),
                  onChanged: (value) => setState(() {
                    if (value != null) _legFactorIds[index] = value;
                    _result = null;
                  }),
                ),
              );
            }),
            const _Notice(
              text:
                  'These legs use the itinerary’s road-route distances. Ferry is intentionally unavailable here; add a separately verified/manual sea-distance segment when a trip crosses water.',
            ),
          ],
          const SizedBox(height: 12),
          TextFormField(
            controller: _distance,
            readOnly: _distanceMode == _DistanceMode.route || hasItineraryLegs,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,3}'))
            ],
            decoration: InputDecoration(
              labelText: 'Distance (km) *',
              helperText: 'Source: ${_distanceSource.replaceAll('_', ' ')}'
                  '${_routeCalculatedAt == null ? '' : ' · ${DateFormat.yMMMd().add_jm().format(_routeCalculatedAt!.toLocal())}'}',
              prefixIcon: const Icon(Icons.straighten_rounded),
            ),
            validator: (value) {
              final parsed = double.tryParse(value ?? '');
              return parsed == null || parsed <= 0 || parsed > 5000
                  ? 'Enter a distance greater than 0 and up to 5,000 km.'
                  : null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _travelers,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Number of travelers *',
              helperText: 'Results show both group total and per traveler.',
              prefixIcon: Icon(Icons.group_rounded),
            ),
            validator: (value) {
              final parsed = int.tryParse(value ?? '');
              return parsed == null || parsed < 1 || parsed > 100
                  ? 'Enter between 1 and 100 travelers.'
                  : null;
            },
          ),
          const SizedBox(height: 12),
          SegmentedButton<TripType>(
            segments: TripType.values
                .map((type) =>
                    ButtonSegment(value: type, label: Text(type.label)))
                .toList(growable: false),
            selected: {_tripType},
            onSelectionChanged: (values) => setState(() {
              _tripType = values.single;
              _result = null;
            }),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: factor == null || _saving
                ? null
                : () => _calculate(catalog, markers, online),
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18, child: CircularProgressIndicator())
                : const Icon(Icons.calculate_rounded),
            label:
                Text(_saving ? 'Saving estimate…' : 'Estimate trip footprint'),
          ),
        ]),
      ),
    ]);
  }

  CarbonFactor? _selectedFactor(CarbonFactorCatalog catalog) {
    for (final item in catalog.items) {
      if (item.id == _factorId) return item;
    }
    return catalog.items.isEmpty ? null : catalog.items.first;
  }

  MapMarker? _marker(List<MapMarker> markers, String? id) {
    for (final marker in markers) {
      if (marker.id == id) return marker;
    }
    return null;
  }

  Future<void> _calculateRoute(List<MapMarker> markers,
      {required bool online}) async {
    final destination = _marker(markers, _destinationId);
    if (destination == null) {
      _feedback('Choose a destination first.');
      return;
    }
    MapCoordinate? origin;
    String originName;
    if (_originKey == 'current') {
      var location = ref.read(userLocationProvider);
      if (!location.hasLocation && online) {
        await ref.read(userLocationProvider.notifier).locate();
        location = ref.read(userLocationProvider);
      }
      if (!location.hasLocation) {
        _feedback('A current location is required for this route.');
        return;
      }
      origin = MapCoordinate(location.latitude!, location.longitude!);
      originName = 'Current location';
    } else {
      final marker = _marker(markers, _originKey);
      if (marker == null) return;
      origin = MapCoordinate(marker.latitude, marker.longitude);
      originName = marker.name;
    }
    final target = MapCoordinate(destination.latitude, destination.longitude);
    final cacheKey = 'carbon:$_originKey:${destination.id}';
    setState(() => _routing = true);
    try {
      double distance;
      if (online) {
        final route = await ref.read(directionsServiceProvider).route(
              origin: origin,
              destination: target,
            );
        await ref.read(routeCacheServiceProvider).save(
              destinationId: cacheKey,
              origin: origin,
              destination: target,
              route: route,
            );
        distance = route.distanceKm;
        _distanceSource = 'osrm';
        _routeCalculatedAt = DateTime.now();
      } else {
        final cached = ref.read(routeCacheServiceProvider).latestFor(cacheKey);
        if (cached == null ||
            (cached.origin.latitude - origin.latitude).abs() > .0001 ||
            (cached.origin.longitude - origin.longitude).abs() > .0001) {
          throw StateError('No matching saved route is available offline.');
        }
        distance = cached.distanceKm;
        _distanceSource = 'cached_route';
        _routeCalculatedAt = cached.calculatedAt;
      }
      if (!mounted) return;
      setState(() {
        _distance.text = distance.toStringAsFixed(3);
        _result = null;
      });
      _feedback(
          '$originName to ${destination.name}: ${distance.toStringAsFixed(2)} km');
    } catch (error) {
      _feedback(error is StateError
          ? error.message
          : 'A road route could not be calculated.');
    } finally {
      if (mounted) setState(() => _routing = false);
    }
  }

  Future<void> _calculate(
      CarbonFactorCatalog catalog, List<MapMarker> markers, bool online) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final factor = _selectedFactor(catalog)!;
    final distance = double.parse(_distance.text);
    final travelers = int.parse(_travelers.text);
    final multiplier = _tripType.distanceMultiplier;
    final usesLegs = _distanceMode == _DistanceMode.itinerary &&
        widget.initialLegDistances.isNotEmpty;
    final legResults = <_CarbonLegResult>[];
    if (usesLegs) {
      for (var index = 0; index < widget.initialLegDistances.length; index++) {
        final legFactor = catalog.items.firstWhere(
          (item) => item.id == _legFactorIds[index],
          orElse: () => factor,
        );
        final legDistance = widget.initialLegDistances[index];
        legResults.add(_CarbonLegResult(
          index: index + 1,
          distanceKm: legDistance,
          factor: legFactor,
          totalKg: legDistance * legFactor.factor * travelers * multiplier,
        ));
      }
    }
    final total = usesLegs
        ? legResults.fold<double>(0, (sum, item) => sum + item.totalKg)
        : distance * factor.factor * travelers * multiplier;
    final comparisons = usesLegs
        ? <MapEntry<String, double>>[]
        : (catalog.items
            .where((item) => item.isFerry == factor.isFerry)
            .where((item) =>
                !item.isActiveTravel ||
                (item.mode == 'walking' ? distance <= 5 : distance <= 20))
            .map((item) => MapEntry(
                  item.name,
                  distance * item.factor * travelers * multiplier,
                ))
            .toList(growable: false)
          ..sort((a, b) => a.value.compareTo(b.value)));
    setState(() {
      _result = _EstimateView(
        factor: factor,
        distanceKm: distance,
        travelers: travelers,
        tripType: _tripType,
        totalKg: total,
        distanceSource: _distanceSource,
        routeCalculatedAt: _routeCalculatedAt,
        comparisons: comparisons,
        legs: legResults,
      );
    });

    final auth = ref.read(authProvider);
    if (!auth.isLoggedIn || auth.role != UserRole.tourist) return;
    if (!online ||
        factor.isBundled ||
        legResults.any((leg) => leg.factor.isBundled) ||
        auth.isOfflineSession) {
      _feedback(
          'Estimate calculated locally. Reconnect to save it to history.');
      return;
    }
    final destination = _marker(markers, _destinationId);
    final origin = _marker(markers, _originKey);
    setState(() => _saving = true);
    try {
      await ref.read(carbonRepositoryProvider).save(auth.userId!, {
        if (!usesLegs) 'emission_factor_id': factor.id,
        'origin_name': _originKey == 'current'
            ? 'Current location'
            : origin?.name ?? 'Manual origin',
        'destination_name': destination?.name ?? 'Manual destination',
        'origin_entity_type': _originKey == 'current'
            ? 'current_location'
            : origin?.itineraryEntityType ?? 'manual',
        if (origin != null) 'origin_entity_id': origin.itineraryEntityId,
        'destination_entity_type': destination?.itineraryEntityType ?? 'manual',
        if (destination != null)
          'destination_entity_id': destination.itineraryEntityId,
        if (!usesLegs) 'distance_km': distance,
        if (!usesLegs)
          'distance_source': factor.isFerry && _distanceSource == 'manual'
              ? 'configured_ferry'
              : _distanceSource,
        if (usesLegs)
          'legs': legResults
              .map((leg) => {
                    'emission_factor_id': leg.factor.id,
                    'distance_km': leg.distanceKm,
                    'distance_source': 'itinerary',
                    'origin_name': 'Itinerary leg ${leg.index} origin',
                    'destination_name':
                        'Itinerary leg ${leg.index} destination',
                  })
              .toList(growable: false),
        if (_routeCalculatedAt != null)
          'route_calculated_at': _routeCalculatedAt!.toUtc().toIso8601String(),
        'travelers': travelers,
        'trip_type': _tripType == TripType.roundTrip ? 'round_trip' : 'one_way',
        if (widget.itineraryId != null) 'itinerary_id': widget.itineraryId,
      });
      await _loadHistory();
      _feedback('Estimate saved to your history.');
    } catch (_) {
      _feedback('Calculated successfully, but history could not be saved.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMethodology(BuildContext context, CarbonFactorCatalog? catalog) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Methodology and limitations',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Text(catalog?.method ??
              'distance × passenger-km factor × travelers × trip multiplier'),
          const SizedBox(height: 8),
          Text(catalog?.disclaimer ??
              'Approximate planning estimates, not audited emissions.'),
          const SizedBox(height: 8),
          const Text(
              'Walking and cycling are zero only for direct vehicle emissions. Food, vehicle manufacture, infrastructure, detours, load, sea conditions, and real fleet performance are excluded. The tricycle value is a disclosed local proxy until a verified Tubigon fleet study is available.'),
          const SizedBox(height: 14),
          ...?catalog?.items.map((item) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${item.name}: ${item.factor} ${item.unit}'),
                subtitle: Text(
                    '${item.sourceName} (${item.sourceYear}) · ${item.assumption ?? item.notes ?? 'No additional assumption'}'),
              )),
        ],
      ),
    );
  }

  void _feedback(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _EstimateView {
  const _EstimateView({
    required this.factor,
    required this.distanceKm,
    required this.travelers,
    required this.tripType,
    required this.totalKg,
    required this.distanceSource,
    required this.routeCalculatedAt,
    required this.comparisons,
    this.legs = const [],
  });

  final CarbonFactor factor;
  final double distanceKm;
  final int travelers;
  final TripType tripType;
  final double totalKg;
  final String distanceSource;
  final DateTime? routeCalculatedAt;
  final List<MapEntry<String, double>> comparisons;
  final List<_CarbonLegResult> legs;

  double get perTravelerKg => totalKg / travelers;
  String get rating => perTravelerKg <= .5
      ? 'Low'
      : perTravelerKg <= 5
          ? 'Moderate'
          : 'High';
}

class _CarbonLegResult {
  const _CarbonLegResult({
    required this.index,
    required this.distanceKm,
    required this.factor,
    required this.totalKg,
  });

  final int index;
  final double distanceKm;
  final CarbonFactor factor;
  final double totalKg;
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});
  final _EstimateView result;

  @override
  Widget build(BuildContext context) {
    final alternatives = result.comparisons
        .where((entry) => entry.key != result.factor.name)
        .take(4)
        .toList(growable: false);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x6634D399)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Estimated group footprint',
            style: TextStyle(color: Color(0xFF94A3B8))),
        Text('${result.totalKg.toStringAsFixed(2)} kg CO₂e',
            style: const TextStyle(
                color: Color(0xFF34D399),
                fontSize: 30,
                fontWeight: FontWeight.w800)),
        Text(
            '${result.perTravelerKg.toStringAsFixed(2)} kg CO₂e per traveler · ${result.rating}',
            style: const TextStyle(color: Colors.white)),
        const SizedBox(height: 8),
        Text(
          '${result.distanceKm.toStringAsFixed(2)} km · ${result.tripType.label} · ${result.legs.isEmpty ? result.factor.name : 'Per-leg modes'}\nDistance source: ${result.distanceSource.replaceAll('_', ' ')} · Factor ${result.legs.isEmpty ? result.factor.version : 'multimodal'}',
          style: const TextStyle(color: Color(0xFFCBD5E1)),
        ),
        if (result.legs.isNotEmpty) ...[
          const Divider(height: 26),
          const Text('Itinerary leg breakdown',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ...result.legs.map((leg) => Text(
                'Leg ${leg.index}: ${leg.distanceKm.toStringAsFixed(2)} km · ${leg.factor.name} · ${leg.totalKg.toStringAsFixed(2)} kg CO₂e',
                style: const TextStyle(color: Color(0xFFCBD5E1)),
              )),
        ],
        if (alternatives.isNotEmpty) ...[
          const Divider(height: 26),
          const Text('Applicable comparisons',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ...alternatives.map((entry) => Text(
                '${entry.key}: ${entry.value.toStringAsFixed(2)} kg CO₂e',
                style: const TextStyle(color: Color(0xFFCBD5E1)),
              )),
          const SizedBox(height: 8),
          Text(
            '${alternatives.first.key} is the lowest modeled applicable alternative. Confirm safety, schedules, accessibility, and actual availability before changing plans.',
            style: const TextStyle(color: Color(0xFFFDE68A)),
          ),
        ],
      ]),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.online});
  final bool online;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF047857), Color(0xFF10B981)]),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(children: [
          const Icon(Icons.co2_rounded, color: Colors.white, size: 42),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              online
                  ? 'Estimate a manual, mapped, or itinerary trip using versioned passenger-kilometer factors.'
                  : 'You are offline. Cached factors and exact matching saved routes remain available; new road routes and history saves do not.',
              style: const TextStyle(color: Colors.white, height: 1.4),
            ),
          ),
        ]),
      );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0x33F59E0B),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(text, style: const TextStyle(color: Color(0xFFFDE68A))),
      );
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard(this.item);
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: const Icon(Icons.history_rounded),
          title: Text(
              '${double.tryParse(item['estimated_kg_co2e']?.toString() ?? '')?.toStringAsFixed(2) ?? '—'} kg CO₂e'),
          subtitle: Text(
              '${item['origin_name'] ?? 'Origin'} → ${item['destination_name'] ?? 'Destination'} · ${item['distance_km'] ?? '—'} km'),
          trailing: Text(item['factor_version']?.toString() ?? ''),
        ),
      );
}

class _StateCard extends StatelessWidget {
  const _StateCard({required this.message, required this.onPressed});
  final String message;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(children: [
          Text(message, style: const TextStyle(color: Colors.white)),
          TextButton(onPressed: onPressed, child: const Text('Retry')),
        ]),
      );
}
