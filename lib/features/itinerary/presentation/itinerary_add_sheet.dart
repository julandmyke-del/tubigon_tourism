import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/exceptions/app_exception.dart';
import '../../authentication/auth_provider.dart';
import '../../map/providers/map_provider.dart';
import '../models/itinerary.dart';
import '../repositories/itinerary_repository.dart';

Future<void> showAddToItinerarySheet(
  BuildContext context,
  WidgetRef ref,
  MapMarker marker, {
  String? reservationId,
}) async {
  if (!marker.isItineraryEligible) return;
  final auth = ref.read(authProvider);
  if (!auth.isLoggedIn || auth.role != UserRole.tourist) {
    final signIn = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text('Sign in to save your trip',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'Guests can explore places, but a permanent itinerary needs a Tourist/User account.',
          style: TextStyle(color: Color(0xFFCBD5E1)),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Not now')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sign in')),
        ],
      ),
    );
    if (signIn == true && context.mounted) context.push('/auth/login');
    return;
  }

  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AddToItinerarySheet(
      marker: marker,
      reservationId: reservationId,
    ),
  );
}

class _AddToItinerarySheet extends ConsumerStatefulWidget {
  const _AddToItinerarySheet({required this.marker, this.reservationId});

  final MapMarker marker;
  final String? reservationId;

  @override
  ConsumerState<_AddToItinerarySheet> createState() =>
      _AddToItinerarySheetState();
}

class _AddToItinerarySheetState extends ConsumerState<_AddToItinerarySheet> {
  String? _itineraryId;
  int _day = 1;
  TimeOfDay? _time;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final itineraries = ref.watch(itinerariesProvider);
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SafeArea(
        top: false,
        child: itineraries.when(
          loading: () => const SizedBox(
              height: 180, child: Center(child: CircularProgressIndicator())),
          error: (_, __) => _error(),
          data: (trips) => _content(trips),
        ),
      ),
    );
  }

  Widget _content(List<Itinerary> trips) {
    final available = trips
        .where((trip) =>
            trip.status != ItineraryStatus.archived &&
            trip.status != ItineraryStatus.completed)
        .toList(growable: false);
    final selected =
        available.where((trip) => trip.id == _itineraryId).firstOrNull;
    if (_itineraryId == null && available.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _itineraryId == null) {
          setState(() => _itineraryId = available.first.id);
        }
      });
    }

    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
          width: 42,
          height: 4,
          decoration: BoxDecoration(
              color: const Color(0xFF475569),
              borderRadius: BorderRadius.circular(8))),
      const SizedBox(height: 16),
      Row(children: [
        const Icon(Icons.playlist_add_rounded, color: Color(0xFFF59E0B)),
        const SizedBox(width: 9),
        const Expanded(
          child: Text('Add to Itinerary',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900)),
        ),
        IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8))),
      ]),
      Align(
        alignment: Alignment.centerLeft,
        child: Text(widget.marker.name,
            style: const TextStyle(
                color: Color(0xFFCBD5E1), fontWeight: FontWeight.w700)),
      ),
      const SizedBox(height: 16),
      if (available.isEmpty)
        _empty()
      else ...[
        DropdownButtonFormField<String>(
          initialValue: selected?.id,
          dropdownColor: const Color(0xFF1E293B),
          decoration: _input('Trip', Icons.luggage_rounded),
          style: const TextStyle(color: Colors.white),
          items: available
              .map((trip) => DropdownMenuItem(
                    value: trip.id,
                    child: Text(trip.name, overflow: TextOverflow.ellipsis),
                  ))
              .toList(growable: false),
          onChanged: (value) => setState(() {
            _itineraryId = value;
            _day = 1;
          }),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<int>(
              initialValue: _day,
              dropdownColor: const Color(0xFF1E293B),
              decoration: _input('Day', Icons.calendar_view_day_rounded),
              style: const TextStyle(color: Colors.white),
              items: List.generate(
                selected?.dayCount ?? 1,
                (index) => DropdownMenuItem(
                    value: index + 1, child: Text('Day ${index + 1}')),
              ),
              onChanged: (value) => setState(() => _day = value ?? 1),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _pickTime,
              icon: const Icon(Icons.schedule_rounded),
              label: Text(
                  _time == null ? 'Optional time' : _time!.format(context)),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 56)),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          TextButton.icon(
              onPressed: _saving ? null : _createTrip,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create new trip')),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: _saving || _itineraryId == null ? null : _add,
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: Colors.black,
                minimumSize: const Size(132, 48)),
            icon: _saving
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.black))
                : const Icon(Icons.playlist_add_check_rounded),
            label: const Text('Add stop'),
          ),
        ]),
      ],
    ]);
  }

  Widget _empty() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(children: [
          const Icon(Icons.luggage_rounded, size: 48, color: Color(0xFF64748B)),
          const SizedBox(height: 10),
          const Text('Create your first Tubigon trip',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          ElevatedButton.icon(
              onPressed: _createTrip,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create trip')),
        ]),
      );

  Widget _error() => SizedBox(
        height: 190,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('Unable to load your itineraries.',
              style: TextStyle(color: Colors.white)),
          const SizedBox(height: 10),
          OutlinedButton.icon(
              onPressed: () => ref.invalidate(itinerariesProvider),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry')),
        ]),
      );

  Future<void> _pickTime() async {
    final value = await showTimePicker(
        context: context, initialTime: _time ?? TimeOfDay.now());
    if (value != null && mounted) setState(() => _time = value);
  }

  Future<void> _createTrip() async {
    final created = await _showCreateTripDialog();
    if (created == null || !mounted) return;
    refreshItineraries(ref, created.id);
    setState(() {
      _itineraryId = created.id;
      _day = 1;
    });
  }

  Future<Itinerary?> _showCreateTripDialog() async {
    final name = TextEditingController(text: 'My Tubigon Trip');
    final description = TextEditingController();
    var start = DateTime.now();
    var end = DateTime.now();
    var busy = false;
    final result = await showDialog<Itinerary>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          title: const Text('Create new trip',
              style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                  controller: name,
                  style: const TextStyle(color: Colors.white),
                  decoration: _input('Trip name', Icons.luggage_rounded)),
              const SizedBox(height: 10),
              TextField(
                  controller: description,
                  maxLines: 2,
                  style: const TextStyle(color: Colors.white),
                  decoration:
                      _input('Description (optional)', Icons.notes_rounded)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final value = await showDatePicker(
                          context: context,
                          firstDate:
                              DateTime.now().subtract(const Duration(days: 1)),
                          lastDate:
                              DateTime.now().add(const Duration(days: 730)),
                          initialDate: start);
                      if (value != null) {
                        setDialogState(() {
                          start = value;
                          if (end.isBefore(start)) end = start;
                        });
                      }
                    },
                    child: Text('Start ${itineraryDate(start)}'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final value = await showDatePicker(
                          context: context,
                          firstDate: start,
                          lastDate: start.add(const Duration(days: 30)),
                          initialDate: end.isBefore(start) ? start : end);
                      if (value != null) setDialogState(() => end = value);
                    },
                    child: Text('End ${itineraryDate(end)}'),
                  ),
                ),
              ]),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: busy ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (name.text.trim().isEmpty) return;
                      setDialogState(() => busy = true);
                      try {
                        final trip = await ref
                            .read(itineraryRepositoryProvider)
                            .createItinerary({
                          'name': name.text.trim(),
                          'description': description.text.trim().isEmpty
                              ? null
                              : description.text.trim(),
                          'start_date': itineraryDate(start),
                          'end_date': itineraryDate(end),
                          'status': start.isAfter(DateTime.now())
                              ? 'upcoming'
                              : 'draft',
                        });
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext, trip);
                        }
                      } catch (_) {
                        setDialogState(() => busy = false);
                      }
                    },
              child: busy
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Create'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    description.dispose();
    return result;
  }

  Future<void> _add({bool allowDuplicate = false}) async {
    final id = _itineraryId;
    if (id == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(itineraryRepositoryProvider).addItem(
            id,
            entityType: widget.marker.itineraryEntityType,
            entityId: widget.marker.itineraryEntityId,
            dayNumber: _day,
            plannedStartTime: _time == null
                ? null
                : '${_time!.hour.toString().padLeft(2, '0')}:${_time!.minute.toString().padLeft(2, '0')}',
            reservationId: widget.reservationId,
            allowDuplicate: allowDuplicate,
          );
      refreshItineraries(ref, id);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${widget.marker.name} added to Day $_day.')));
    } on AppException catch (error) {
      if (error.statusCode == 409 && mounted) {
        final addAgain = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Place already added'),
            content: Text(error.message),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('View existing')),
              ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Add again anyway')),
            ],
          ),
        );
        if (addAgain == true) {
          if (mounted) setState(() => _saving = false);
          return _add(allowDuplicate: true);
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Unable to add this stop right now.')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

InputDecoration _input(String label, IconData icon) => InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
      prefixIcon: Icon(icon, color: const Color(0xFFF59E0B)),
      filled: true,
      fillColor: const Color(0xFF1E293B),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    );
