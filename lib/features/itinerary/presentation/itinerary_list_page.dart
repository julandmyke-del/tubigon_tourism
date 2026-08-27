import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/itinerary.dart';
import '../repositories/itinerary_repository.dart';

class ItineraryListPage extends ConsumerWidget {
  const ItineraryListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trips = ref.watch(itinerariesProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF080F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('My Itineraries',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w900)),
            Text('Plan and navigate your Tubigon trip',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/itineraries/create'),
        backgroundColor: const Color(0xFFF59E0B),
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Trip'),
      ),
      body: trips.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) =>
            _Error(onRetry: () => ref.invalidate(itinerariesProvider)),
        data: (items) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(itinerariesProvider);
            await ref.read(itinerariesProvider.future);
          },
          child: items.isEmpty
              ? const _Empty()
              : ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 96),
                  children: [
                    const _OfflineNote(),
                    const SizedBox(height: 18),
                    for (final status in ItineraryStatus.values)
                      if (items.any((trip) => trip.status == status)) ...[
                        _SectionTitle(status: status),
                        const SizedBox(height: 8),
                        for (final trip
                            in items.where((trip) => trip.status == status))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _TripCard(
                              trip: trip,
                              onTap: () =>
                                  context.push('/itineraries/${trip.id}'),
                            ),
                          ),
                        const SizedBox(height: 8),
                      ],
                  ],
                ),
        ),
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({required this.trip, required this.onTap});

  final Itinerary trip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = _statusColor(trip.status);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: accent.withValues(alpha: .42)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: .25),
                  blurRadius: 18,
                  offset: const Offset(0, 8)),
            ],
          ),
          child: Row(children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  accent.withValues(alpha: .9),
                  accent.withValues(alpha: .45),
                ]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.luggage_rounded, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(trip.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 5),
                  Text(
                    '${DateFormat('MMM d').format(trip.startDate)}–${DateFormat('MMM d, y').format(trip.endDate)}',
                    style: const TextStyle(color: Color(0xFFCBD5E1)),
                  ),
                  const SizedBox(height: 7),
                  Wrap(spacing: 10, runSpacing: 5, children: [
                    _Meta(
                        '${trip.dayCount} day${trip.dayCount == 1 ? '' : 's'}',
                        Icons.calendar_today_rounded),
                    _Meta(
                        '${trip.placeCount} place${trip.placeCount == 1 ? '' : 's'}',
                        Icons.place_rounded),
                    if (trip.travelers != null)
                      _Meta('${trip.travelers} travelers', Icons.group_rounded),
                  ]),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF64748B)),
          ]),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta(this.label, this.icon);
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: const Color(0xFFF59E0B)),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
      ]);
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.status});
  final ItineraryStatus status;

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
                color: _statusColor(status), shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(_title(status),
            style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w900)),
      ]);
}

class _OfflineNote extends StatelessWidget {
  const _OfflineNote();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: const Color(0xFF172554).withValues(alpha: .55),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: const Color(0xFF3B82F6).withValues(alpha: .3))),
        child: const Row(children: [
          Icon(Icons.offline_pin_rounded, color: Color(0xFF60A5FA), size: 20),
          SizedBox(width: 9),
          Expanded(
              child: Text(
                  'Saved trip details remain readable offline. Live maps and directions need internet.',
                  style: TextStyle(color: Color(0xFFBFDBFE), fontSize: 11))),
        ]),
      );
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(28),
        children: [
          const SizedBox(height: 90),
          const Icon(Icons.luggage_rounded, size: 72, color: Color(0xFF475569)),
          const SizedBox(height: 16),
          const Text('Plan your first Tubigon trip',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text(
              'Create a trip, then add places from Explore or Smart Map.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF94A3B8))),
          const SizedBox(height: 18),
          Center(
            child: ElevatedButton.icon(
                onPressed: () => context.push('/itineraries/create'),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create itinerary')),
          ),
        ],
      );
}

class _Error extends StatelessWidget {
  const _Error({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cloud_off_rounded,
              size: 58, color: Color(0xFF64748B)),
          const SizedBox(height: 14),
          const Text('Unable to load your itineraries.',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry')),
        ]),
      );
}

String _title(ItineraryStatus status) => switch (status) {
      ItineraryStatus.draft => 'Drafts',
      ItineraryStatus.upcoming => 'Upcoming',
      ItineraryStatus.active => 'Active',
      ItineraryStatus.completed => 'Completed',
      ItineraryStatus.archived => 'Archived',
    };

Color _statusColor(ItineraryStatus status) => switch (status) {
      ItineraryStatus.draft => const Color(0xFF94A3B8),
      ItineraryStatus.upcoming => const Color(0xFFF59E0B),
      ItineraryStatus.active => const Color(0xFF22C55E),
      ItineraryStatus.completed => const Color(0xFF38BDF8),
      ItineraryStatus.archived => const Color(0xFF64748B),
    };
