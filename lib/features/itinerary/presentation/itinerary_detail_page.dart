import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/exceptions/app_exception.dart';
import '../../map/providers/map_provider.dart';
import '../../map/services/directions_service.dart';
import '../models/itinerary.dart';
import '../repositories/itinerary_repository.dart';

class ItineraryDetailPage extends ConsumerStatefulWidget {
  const ItineraryDetailPage({super.key, required this.itineraryId});

  final String itineraryId;

  @override
  ConsumerState<ItineraryDetailPage> createState() =>
      _ItineraryDetailPageState();
}

class _ItineraryDetailPageState extends ConsumerState<ItineraryDetailPage> {
  bool _mapView = false;
  int _day = 1;
  bool _routeLoading = false;
  MapRouteResult? _route;
  String? _routeFingerprint;
  String? _routeError;

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(itineraryDetailProvider(widget.itineraryId));
    return Scaffold(
      backgroundColor: const Color(0xFF080F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text('Trip Planner'),
        actions: [
          IconButton(
              tooltip: 'Refresh',
              onPressed: () =>
                  ref.invalidate(itineraryDetailProvider(widget.itineraryId)),
              icon: const Icon(Icons.refresh_rounded)),
          PopupMenuButton<String>(
            onSelected: (action) => value.valueOrNull == null
                ? null
                : _tripAction(value.valueOrNull!, action),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'complete', child: Text('Mark completed')),
              PopupMenuItem(value: 'archive', child: Text('Archive trip')),
            ],
          ),
        ],
      ),
      body: value.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _Error(onRetry: () {
          ref.invalidate(itineraryDetailProvider(widget.itineraryId));
        }),
        data: (trip) => _body(trip),
      ),
    );
  }

  Widget _body(Itinerary trip) {
    if (_day > trip.dayCount) {
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => mounted ? setState(() => _day = 1) : null);
    }
    if (_mapView) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _calculateRoute(trip));
    }
    final nextStop = trip.items
        .where((item) =>
            item.visitStatus == ItineraryVisitStatus.planned &&
            item.place != null)
        .firstOrNull;

    return Column(children: [
      _TripHeader(trip: trip),
      if (trip.status == ItineraryStatus.active && nextStop != null)
        _NextStop(
          item: nextStop,
          onNavigate: () => _openMap(nextStop, directions: true),
          onVisited: () => _setVisitStatus(trip, nextStop, 'visited'),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Row(children: [
          Expanded(
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                    value: false,
                    icon: Icon(Icons.view_list_rounded),
                    label: Text('LIST')),
                ButtonSegment(
                    value: true,
                    icon: Icon(Icons.map_rounded),
                    label: Text('MAP')),
              ],
              selected: {_mapView},
              onSelectionChanged: (selection) =>
                  setState(() => _mapView = selection.first),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            onPressed: trip.status == ItineraryStatus.active
                ? null
                : () => _startTrip(trip),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Start Trip'),
          ),
        ]),
      ),
      _DayBar(
        dayCount: trip.dayCount,
        selected: _day,
        onSelected: (day) => setState(() {
          _day = day;
          _route = null;
          _routeFingerprint = null;
        }),
      ),
      Expanded(child: _mapView ? _map(trip) : _list(trip)),
    ]);
  }

  Widget _list(Itinerary trip) {
    final items = trip.itemsForDay(_day);
    final warnings = _scheduleWarnings(items, _route);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(itineraryDetailProvider(widget.itineraryId));
        await ref.read(itineraryDetailProvider(widget.itineraryId).future);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          if (warnings.isNotEmpty) _Warnings(warnings: warnings),
          if (warnings.isNotEmpty) const SizedBox(height: 10),
          if (items.isEmpty)
            _EmptyDay(
              day: _day,
              onExplore: () => context.push('/explore'),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: items.length,
              onReorderItem: (oldIndex, newIndex) =>
                  _reorder(trip, items, oldIndex, newIndex),
              itemBuilder: (context, index) {
                final item = items[index];
                return Padding(
                  key: ValueKey(item.id),
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _StopCard(
                    number: index + 1,
                    item: item,
                    dragHandle: ReorderableDragStartListener(
                      index: index,
                      child: const Icon(Icons.drag_handle_rounded,
                          color: Color(0xFF64748B)),
                    ),
                    onMap: item.place == null ? null : () => _openMap(item),
                    onDirections: item.place == null
                        ? null
                        : () => _openMap(item, directions: true),
                    onEdit: () => _editItem(trip, item),
                    onRemove: () => _removeItem(trip, item),
                    onVisited: () => _setVisitStatus(trip, item, 'visited'),
                    onSkipped: () => _setVisitStatus(trip, item, 'skipped'),
                    onReservation: item.reservation == null
                        ? null
                        : () => context
                            .push('/reservations/${item.reservation!.id}'),
                  ),
                );
              },
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
              onPressed: () => context.push('/explore'),
              icon: const Icon(Icons.add_location_alt_rounded),
              label: const Text('Find places in Explore')),
        ],
      ),
    );
  }

  Widget _map(Itinerary trip) {
    final items =
        trip.itemsForDay(_day).where((item) => item.place != null).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _card(accent: const Color(0xFF0EA5E9)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Expanded(
                child: Text('DAY ROUTE',
                    style: TextStyle(
                        color: Color(0xFF38BDF8),
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2)),
              ),
              TextButton.icon(
                  onPressed: () => _chooseStart(trip),
                  icon: const Icon(Icons.trip_origin_rounded),
                  label: Text(_startLabel(trip))),
            ]),
            const SizedBox(height: 10),
            if (items.isEmpty)
              const Text('Add coordinate-bearing places to calculate a route.',
                  style: TextStyle(color: Color(0xFFCBD5E1)))
            else
              for (var index = 0; index < items.length; index++) ...[
                _NumberedStop(number: index + 1, item: items[index]),
                if (index < items.length - 1)
                  Padding(
                    padding: const EdgeInsets.only(left: 17),
                    child: SizedBox(
                      height: 28,
                      child: Row(children: [
                        const VerticalDivider(
                            color: Color(0xFFF59E0B), thickness: 2),
                        const SizedBox(width: 8),
                        if (_route != null && index < _route!.legs.length)
                          Text(
                              '${_route!.legs[index].distanceKm.toStringAsFixed(1)} km · ${_route!.legs[index].durationMinutes} min',
                              style: const TextStyle(
                                  color: Color(0xFF94A3B8), fontSize: 11)),
                      ]),
                    ),
                  ),
              ],
          ]),
        ),
        const SizedBox(height: 12),
        _RouteSummary(
          loading: _routeLoading,
          route: _route,
          error: _routeError,
          onRefresh: () {
            _routeFingerprint = null;
            _calculateRoute(trip);
          },
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: items.isEmpty
              ? null
              : () => context.push('/itineraries/${trip.id}/map?day=$_day'),
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: Colors.black,
              minimumSize: const Size.fromHeight(52)),
          icon: const Icon(Icons.map_rounded),
          label: const Text('Open on Smart Map'),
        ),
        const SizedBox(height: 8),
        const Text(
          'Route estimates are driving estimates from OSRM. They do not include traffic, stops, meals, ferry delays, weather, or sightseeing time.',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 10, height: 1.4),
        ),
      ],
    );
  }

  Future<void> _calculateRoute(Itinerary trip) async {
    final items =
        trip.itemsForDay(_day).where((item) => item.place != null).toList();
    if (items.length < 2) {
      if (_route != null) setState(() => _route = null);
      return;
    }
    final user = ref.read(userLocationProvider);
    final fingerprint = [
      _day,
      trip.startLocationType,
      if (trip.startLocationType == 'current_location' && user.hasLocation)
        '${user.latitude!.toStringAsFixed(4)},${user.longitude!.toStringAsFixed(4)}',
      ...items.map((item) => '${item.id}:${item.sortOrder}')
    ].join('|');
    if (_routeLoading || _routeFingerprint == fingerprint) return;

    final points = items
        .map((item) =>
            MapCoordinate(item.place!.latitude, item.place!.longitude))
        .toList();
    if (trip.startLocationType == 'current_location') {
      if (!user.hasLocation) {
        setState(() => _routeError =
            'Enable your location to calculate a route from your current position.');
        return;
      }
      points.insert(0, MapCoordinate(user.latitude!, user.longitude!));
    } else if (trip.startLocationType == 'custom' &&
        trip.startLatitude != null &&
        trip.startLongitude != null) {
      points.insert(
          0, MapCoordinate(trip.startLatitude!, trip.startLongitude!));
    }

    setState(() {
      _routeLoading = true;
      _routeError = null;
    });
    try {
      final route =
          await ref.read(directionsServiceProvider).routeThrough(points);
      if (!mounted) return;
      setState(() {
        _route = route;
        _routeFingerprint = fingerprint;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _routeError =
            'Unable to calculate this route right now. Check your connection and retry.');
      }
    } finally {
      if (mounted) setState(() => _routeLoading = false);
    }
  }

  Future<void> _chooseStart(Itinerary trip) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      builder: (context) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const ListTile(
              title: Text('Starting location',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w900))),
          ListTile(
              leading:
                  const Icon(Icons.looks_one_rounded, color: Color(0xFFF59E0B)),
              title: const Text('First itinerary stop',
                  style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, 'first_stop')),
          ListTile(
              leading: const Icon(Icons.my_location_rounded,
                  color: Color(0xFF38BDF8)),
              title: const Text('My current location',
                  style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, 'current_location')),
          ListTile(
              leading: const Icon(Icons.add_location_alt_rounded,
                  color: Color(0xFF22C55E)),
              title: const Text('Choose location on map',
                  style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, 'custom')),
        ]),
      ),
    );
    if (choice == null || !mounted) return;
    final data = <String, dynamic>{'start_location_type': choice};
    if (choice == 'current_location') {
      final found = await ref.read(userLocationProvider.notifier).locate();
      if (!found) return;
    } else if (choice == 'custom') {
      final result =
          await context.push<Map<String, dynamic>>('/map/pick?mode=itinerary');
      if (result == null) return;
      data.addAll({
        'start_location_name': 'Custom map pin',
        'start_latitude': result['latitude'],
        'start_longitude': result['longitude'],
      });
    }
    await _updateTrip(trip, data);
    _routeFingerprint = null;
  }

  Future<void> _reorder(Itinerary trip, List<ItineraryItem> items, int oldIndex,
      int newIndex) async {
    final reordered = List<ItineraryItem>.of(items);
    final item = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, item);
    try {
      await ref.read(itineraryRepositoryProvider).reorderItems(trip.id, [
        for (var index = 0; index < reordered.length; index++)
          {
            'id': reordered[index].id,
            'day_number': _day,
            'sort_order': index + 1,
          }
      ]);
      _refresh(trip.id);
      _routeFingerprint = null;
    } on AppException catch (error) {
      _message(error.message);
    }
  }

  Future<void> _editItem(Itinerary trip, ItineraryItem item) async {
    var day = item.dayNumber;
    var start = _parseTime(item.plannedStartTime);
    var end = _parseTime(item.plannedEndTime);
    final notes = TextEditingController(text: item.notes);
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
          child: SafeArea(
            top: false,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(item.place?.name ?? 'Edit stop',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 14),
              DropdownButtonFormField<int>(
                initialValue: day,
                dropdownColor: const Color(0xFF1E293B),
                decoration: _input('Trip day', Icons.calendar_view_day_rounded),
                items: List.generate(
                    trip.dayCount,
                    (index) => DropdownMenuItem(
                        value: index + 1, child: Text('Day ${index + 1}'))),
                onChanged: (value) => setSheetState(() => day = value ?? day),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                    child: _TimeButton(
                        label: 'Arrival',
                        value: start,
                        onTap: () async {
                          final value = await showTimePicker(
                              context: context,
                              initialTime: start ?? TimeOfDay.now());
                          if (value != null) setSheetState(() => start = value);
                        })),
                const SizedBox(width: 8),
                Expanded(
                    child: _TimeButton(
                        label: 'Departure',
                        value: end,
                        onTap: () async {
                          final value = await showTimePicker(
                              context: context,
                              initialTime: end ?? start ?? TimeOfDay.now());
                          if (value != null) setSheetState(() => end = value);
                        })),
              ]),
              const SizedBox(height: 10),
              TextField(
                  controller: notes,
                  maxLines: 3,
                  style: const TextStyle(color: Colors.white),
                  decoration: _input('Notes (optional)', Icons.notes_rounded)),
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, {
                  'day_number': day,
                  'planned_start_time': _apiTime(start),
                  'planned_end_time': _apiTime(end),
                  'notes': notes.text.trim().isEmpty ? null : notes.text.trim(),
                }),
                child: const Text('Save stop'),
              ),
            ]),
          ),
        ),
      ),
    );
    notes.dispose();
    if (result == null) return;
    try {
      await ref
          .read(itineraryRepositoryProvider)
          .updateItem(trip.id, item.id, result);
      _refresh(trip.id);
      _routeFingerprint = null;
    } on AppException catch (error) {
      _message(error.message);
    }
  }

  Future<void> _removeItem(Itinerary trip, ItineraryItem item) async {
    final remove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove stop?'),
        content: Text(
            'Remove ${item.place?.name ?? 'this unavailable place'} from the itinerary?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove')),
        ],
      ),
    );
    if (remove != true) return;
    try {
      await ref.read(itineraryRepositoryProvider).removeItem(trip.id, item.id);
      _refresh(trip.id);
      _routeFingerprint = null;
    } on AppException catch (error) {
      _message(error.message);
    }
  }

  Future<void> _setVisitStatus(
      Itinerary trip, ItineraryItem item, String status) async {
    try {
      await ref
          .read(itineraryRepositoryProvider)
          .updateItem(trip.id, item.id, {'visit_status': status});
      _refresh(trip.id);
    } on AppException catch (error) {
      _message(error.message);
    }
  }

  Future<void> _startTrip(Itinerary trip) async {
    await _updateTrip(trip, {'status': 'active'});
  }

  Future<void> _tripAction(Itinerary trip, String action) async {
    if (action == 'complete') {
      await _updateTrip(trip, {'status': 'completed'});
    } else if (action == 'archive') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Archive itinerary?'),
          content:
              const Text('The trip will be removed from your active planner.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Archive')),
          ],
        ),
      );
      if (confirmed == true) {
        await ref.read(itineraryRepositoryProvider).archiveItinerary(trip.id);
        refreshItineraries(ref);
        if (mounted) context.pop();
      }
    }
  }

  Future<void> _updateTrip(Itinerary trip, Map<String, dynamic> data) async {
    try {
      await ref
          .read(itineraryRepositoryProvider)
          .updateItinerary(trip.id, data);
      _refresh(trip.id);
    } on AppException catch (error) {
      _message(error.message);
    }
  }

  void _openMap(ItineraryItem item, {bool directions = false}) {
    final marker = item.place?.markerId;
    if (marker == null || marker.isEmpty) {
      _message('This place is no longer available.');
      return;
    }
    context.push(
        '/map?marker=${Uri.encodeQueryComponent(marker)}${directions ? '&navigate=true' : ''}');
  }

  void _refresh(String id) => refreshItineraries(ref, id);

  void _message(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }
}

class _TripHeader extends StatelessWidget {
  const _TripHeader({required this.trip});
  final Itinerary trip;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [
            Color(0xFF172554),
            Color(0xFF0F172A),
            Color(0xFF431407)
          ]),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(trip.name.toUpperCase(),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w900)),
            ),
            _StatusBadge(status: trip.status),
          ]),
          if (trip.description?.trim().isNotEmpty ?? false) ...[
            const SizedBox(height: 5),
            Text(trip.description!,
                style: const TextStyle(color: Color(0xFFCBD5E1))),
          ],
          const SizedBox(height: 9),
          Wrap(spacing: 14, runSpacing: 6, children: [
            Text(
                '${DateFormat('MMM d').format(trip.startDate)}–${DateFormat('MMM d, y').format(trip.endDate)}',
                style: const TextStyle(
                    color: Color(0xFFFBBF24), fontWeight: FontWeight.w700)),
            Text('${trip.placeCount} places',
                style: const TextStyle(color: Color(0xFF94A3B8))),
            Text('${trip.dayCount} days',
                style: const TextStyle(color: Color(0xFF94A3B8))),
          ]),
        ]),
      );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final ItineraryStatus status;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withValues(alpha: .8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFF59E0B))),
        child: Text(status.name.toUpperCase(),
            style: const TextStyle(
                color: Color(0xFFF59E0B),
                fontSize: 9,
                fontWeight: FontWeight.w900)),
      );
}

class _DayBar extends StatelessWidget {
  const _DayBar(
      {required this.dayCount,
      required this.selected,
      required this.onSelected});
  final int dayCount;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 48,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          scrollDirection: Axis.horizontal,
          itemCount: dayCount,
          separatorBuilder: (_, __) => const SizedBox(width: 7),
          itemBuilder: (context, index) => ChoiceChip(
            selected: selected == index + 1,
            onSelected: (_) => onSelected(index + 1),
            label: Text('Day ${index + 1}'),
            selectedColor: const Color(0xFFF59E0B),
          ),
        ),
      );
}

class _StopCard extends StatelessWidget {
  const _StopCard({
    required this.number,
    required this.item,
    required this.dragHandle,
    required this.onMap,
    required this.onDirections,
    required this.onEdit,
    required this.onRemove,
    required this.onVisited,
    required this.onSkipped,
    required this.onReservation,
  });
  final int number;
  final ItineraryItem item;
  final Widget dragHandle;
  final VoidCallback? onMap;
  final VoidCallback? onDirections;
  final VoidCallback onEdit;
  final VoidCallback onRemove;
  final VoidCallback onVisited;
  final VoidCallback onSkipped;
  final VoidCallback? onReservation;

  @override
  Widget build(BuildContext context) {
    final place = item.place;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: _card(
          accent: item.visitStatus == ItineraryVisitStatus.visited
              ? const Color(0xFF22C55E)
              : const Color(0xFFF59E0B)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(
          backgroundColor: const Color(0xFFF59E0B),
          foregroundColor: Colors.black,
          child: Text('$number',
              style: const TextStyle(fontWeight: FontWeight.w900)),
        ),
        const SizedBox(width: 11),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(place?.name ?? 'This place is no longer available',
                    style: TextStyle(
                        color: place == null
                            ? const Color(0xFFFB7185)
                            : Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900)),
              ),
              dragHandle,
              PopupMenuButton<String>(
                onSelected: (value) => switch (value) {
                  'edit' => onEdit(),
                  'visited' => onVisited(),
                  'skipped' => onSkipped(),
                  'remove' => onRemove(),
                  _ => null,
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                      value: 'edit', child: Text('Edit day/time/notes')),
                  PopupMenuItem(value: 'visited', child: Text('Mark visited')),
                  PopupMenuItem(value: 'skipped', child: Text('Mark skipped')),
                  PopupMenuItem(value: 'remove', child: Text('Remove')),
                ],
              ),
            ]),
            const SizedBox(height: 3),
            Text(place?.category ?? item.entityType,
                style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 11)),
            if (item.plannedStartTime != null ||
                item.plannedEndTime != null) ...[
              const SizedBox(height: 6),
              Text(_timeRange(item),
                  style: const TextStyle(
                      color: Color(0xFF38BDF8), fontWeight: FontWeight.w700)),
            ],
            if (item.notes?.trim().isNotEmpty ?? false) ...[
              const SizedBox(height: 5),
              Text(item.notes!,
                  style:
                      const TextStyle(color: Color(0xFFCBD5E1), fontSize: 11)),
            ],
            if (item.reservation != null) ...[
              const SizedBox(height: 7),
              ActionChip(
                onPressed: onReservation,
                avatar: const Icon(Icons.event_available_rounded,
                    size: 16, color: Color(0xFF22C55E)),
                label: Text(
                    'Reservation · ${item.reservation!.status ?? 'linked'}'),
              ),
            ],
            const SizedBox(height: 8),
            Row(children: [
              _VisitBadge(status: item.visitStatus),
              const Spacer(),
              IconButton.filledTonal(
                  tooltip: 'View on Map',
                  onPressed: onMap,
                  icon: const Icon(Icons.map_rounded, size: 18)),
              const SizedBox(width: 5),
              IconButton.filledTonal(
                  tooltip: 'Directions',
                  onPressed: onDirections,
                  icon: const Icon(Icons.directions_rounded, size: 18)),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _VisitBadge extends StatelessWidget {
  const _VisitBadge({required this.status});
  final ItineraryVisitStatus status;

  @override
  Widget build(BuildContext context) => Text(status.name.toUpperCase(),
      style: TextStyle(
          color: switch (status) {
            ItineraryVisitStatus.visited => const Color(0xFF22C55E),
            ItineraryVisitStatus.skipped => const Color(0xFFFB7185),
            ItineraryVisitStatus.planned => const Color(0xFF94A3B8),
          },
          fontSize: 9,
          fontWeight: FontWeight.w900));
}

class _NextStop extends StatelessWidget {
  const _NextStop(
      {required this.item, required this.onNavigate, required this.onVisited});
  final ItineraryItem item;
  final VoidCallback onNavigate;
  final VoidCallback onVisited;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.all(13),
        decoration: _card(accent: const Color(0xFF22C55E)),
        child: Row(children: [
          const Icon(Icons.navigation_rounded, color: Color(0xFF22C55E)),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('NEXT STOP',
                    style: TextStyle(
                        color: Color(0xFF22C55E),
                        fontSize: 9,
                        fontWeight: FontWeight.w900)),
                Text(item.place!.name,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w800)),
              ])),
          IconButton(
              onPressed: onVisited,
              tooltip: 'Mark Visited',
              icon: const Icon(Icons.check_circle_rounded)),
          ElevatedButton(onPressed: onNavigate, child: const Text('Navigate')),
        ]),
      );
}

class _NumberedStop extends StatelessWidget {
  const _NumberedStop({required this.number, required this.item});
  final int number;
  final ItineraryItem item;
  @override
  Widget build(BuildContext context) => Row(children: [
        CircleAvatar(
            radius: 17,
            backgroundColor: const Color(0xFFF59E0B),
            foregroundColor: Colors.black,
            child: Text('$number',
                style: const TextStyle(fontWeight: FontWeight.w900))),
        const SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.place!.name,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w800)),
          Text(item.place!.category,
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
        ])),
      ]);
}

class _RouteSummary extends StatelessWidget {
  const _RouteSummary(
      {required this.loading,
      required this.route,
      required this.error,
      required this.onRefresh});
  final bool loading;
  final MapRouteResult? route;
  final String? error;
  final VoidCallback onRefresh;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(15),
        decoration: _card(),
        child: loading
            ? const Row(children: [
                CircularProgressIndicator(),
                SizedBox(width: 12),
                Text('Calculating route…',
                    style: TextStyle(color: Colors.white))
              ])
            : error != null
                ? Row(children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Color(0xFFFBBF24)),
                    const SizedBox(width: 9),
                    Expanded(
                        child: Text(error!,
                            style: const TextStyle(color: Color(0xFFCBD5E1)))),
                    IconButton(
                        onPressed: onRefresh,
                        icon: const Icon(Icons.refresh_rounded)),
                  ])
                : route == null
                    ? const Text('Add at least two places for a route summary.',
                        style: TextStyle(color: Color(0xFF94A3B8)))
                    : Row(children: [
                        const Icon(Icons.route_rounded,
                            color: Color(0xFFF59E0B), size: 32),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(
                                  'Total distance: ${route!.distanceKm.toStringAsFixed(1)} km',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800)),
                              Text(
                                  'Estimated driving time: ${route!.durationMinutes} min',
                                  style: const TextStyle(
                                      color: Color(0xFFCBD5E1))),
                            ])),
                        IconButton(
                            onPressed: onRefresh,
                            icon: const Icon(Icons.refresh_rounded)),
                      ]),
      );
}

class _Warnings extends StatelessWidget {
  const _Warnings({required this.warnings});
  final List<String> warnings;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: _card(accent: const Color(0xFFFBBF24)),
        child: Column(children: [
          for (final warning in warnings)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.warning_amber_rounded,
                    color: Color(0xFFFBBF24), size: 18),
                const SizedBox(width: 7),
                Expanded(
                    child: Text(warning,
                        style: const TextStyle(
                            color: Color(0xFFFDE68A), fontSize: 11))),
              ]),
            ),
        ]),
      );
}

class _EmptyDay extends StatelessWidget {
  const _EmptyDay({required this.day, required this.onExplore});
  final int day;
  final VoidCallback onExplore;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(28),
        decoration: _card(),
        child: Column(children: [
          const Icon(Icons.add_location_alt_rounded,
              size: 54, color: Color(0xFF64748B)),
          const SizedBox(height: 10),
          Text('Day $day has no stops yet.',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          ElevatedButton(
              onPressed: onExplore, child: const Text('Explore places')),
        ]),
      );
}

class _TimeButton extends StatelessWidget {
  const _TimeButton(
      {required this.label, required this.value, required this.onTap});
  final String label;
  final TimeOfDay? value;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.schedule_rounded),
        label: Text(value == null ? label : value!.format(context)),
        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
      );
}

class _Error extends StatelessWidget {
  const _Error({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.cloud_off_rounded, size: 58, color: Color(0xFF64748B)),
        const SizedBox(height: 12),
        const Text('Unable to load this itinerary.',
            style: TextStyle(color: Colors.white)),
        const SizedBox(height: 12),
        OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry')),
      ]));
}

List<String> _scheduleWarnings(
    List<ItineraryItem> items, MapRouteResult? route) {
  final warnings = <String>[];
  final timed = items.where((item) => item.plannedStartTime != null).toList()
    ..sort((a, b) =>
        _minutes(a.plannedStartTime!).compareTo(_minutes(b.plannedStartTime!)));
  for (var index = 0; index < timed.length - 1; index++) {
    final end = timed[index].plannedEndTime;
    if (end != null &&
        _minutes(end) > _minutes(timed[index + 1].plannedStartTime!)) {
      warnings.add(
          '${timed[index].place?.name ?? 'A stop'} overlaps with ${timed[index + 1].place?.name ?? 'the next stop'}.');
    }
  }
  if (route != null) {
    final ordered = items.where((item) => item.place != null).toList();
    for (var index = 0;
        index < ordered.length - 1 && index < route.legs.length;
        index++) {
      final end = ordered[index].plannedEndTime;
      final next = ordered[index + 1].plannedStartTime;
      if (end != null &&
          next != null &&
          _minutes(end) + route.legs[index].durationMinutes > _minutes(next)) {
        warnings.add(
            'You may not have enough travel time between ${ordered[index].place!.name} and ${ordered[index + 1].place!.name}.');
      }
    }
  }
  for (final item in items) {
    final arrival = item.plannedStartTime;
    final hours = item.place?.operatingHours;
    if (arrival == null || hours == null) continue;
    final match = RegExp(r'(\d{1,2}):(\d{2})\s*[-–]\s*(\d{1,2}):(\d{2})')
        .firstMatch(hours);
    if (match == null) continue;
    final open = int.parse(match.group(1)!) * 60 + int.parse(match.group(2)!);
    final close = int.parse(match.group(3)!) * 60 + int.parse(match.group(4)!);
    final planned = _minutes(arrival);
    if (planned < open || planned > close) {
      warnings.add(
          '${item.place!.name} may be closed at the planned arrival time.');
    }
  }
  return warnings.toSet().toList(growable: false);
}

int _minutes(String value) {
  final parts = value.split(':');
  return int.parse(parts[0]) * 60 + int.parse(parts[1]);
}

String _timeRange(ItineraryItem item) {
  String format(String raw) {
    final parts = raw.split(':');
    final date = DateTime(2000, 1, 1, int.parse(parts[0]), int.parse(parts[1]));
    return DateFormat.jm().format(date);
  }

  if (item.plannedStartTime != null && item.plannedEndTime != null) {
    return '${format(item.plannedStartTime!)}–${format(item.plannedEndTime!)}';
  }
  return format(item.plannedStartTime ?? item.plannedEndTime!);
}

TimeOfDay? _parseTime(String? value) {
  if (value == null) return null;
  final parts = value.split(':');
  return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
}

String? _apiTime(TimeOfDay? value) => value == null
    ? null
    : '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

String _startLabel(Itinerary trip) => switch (trip.startLocationType) {
      'current_location' => 'Current location',
      'custom' => trip.startLocationName ?? 'Custom pin',
      _ => 'First stop',
    };

InputDecoration _input(String label, IconData icon) => InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
      prefixIcon: Icon(icon, color: const Color(0xFFF59E0B)),
      filled: true,
      fillColor: const Color(0xFF1E293B),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    );

BoxDecoration _card({Color accent = const Color(0xFF334155)}) => BoxDecoration(
      color: const Color(0xFF0F172A),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: accent.withValues(alpha: .45)),
      boxShadow: [
        BoxShadow(
            color: Colors.black.withValues(alpha: .22),
            blurRadius: 16,
            offset: const Offset(0, 7))
      ],
    );
