import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/lgu_providers.dart';

class LguReservationMonitoringPage extends ConsumerStatefulWidget {
  const LguReservationMonitoringPage({super.key});

  @override
  ConsumerState<LguReservationMonitoringPage> createState() =>
      _LguReservationMonitoringPageState();
}

class _LguReservationMonitoringPageState
    extends ConsumerState<LguReservationMonitoringPage> {
  String _query = '';
  String _status = 'all';

  @override
  Widget build(BuildContext context) {
    final reservations = ref.watch(lguReservationsProvider);
    final statuses = ref.watch(lguReservationStatusesProvider).valueOrNull ??
        const <Map<String, dynamic>>[];
    return Scaffold(
      backgroundColor: const Color(0xFF0B132B),
      appBar: AppBar(
        title: const Text('Municipal Spot Reservations'),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(lguReservationsProvider),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          Wrap(spacing: 12, runSpacing: 12, children: [
            SizedBox(
              width: 420,
              child: TextField(
                decoration: const InputDecoration(
                    labelText: 'Search reference, tourist, or destination'),
                onChanged: (value) =>
                    setState(() => _query = value.toLowerCase()),
              ),
            ),
            SizedBox(
              width: 210,
              child: DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: [
                  const DropdownMenuItem(
                      value: 'all', child: Text('All statuses')),
                  ...statuses.map((item) => DropdownMenuItem(
                        value: item['name'].toString(),
                        child: Text(_label(item['name'].toString())),
                      )),
                ],
                onChanged: (value) => setState(() => _status = value ?? 'all'),
              ),
            ),
          ]),
          const SizedBox(height: 14),
          Expanded(
            child: reservations.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text(error.toString())),
              data: (items) {
                final filtered = items.where((item) {
                  final status = _statusName(item);
                  final user = item['user'] is Map
                      ? Map<String, dynamic>.from(item['user'])
                      : const <String, dynamic>{};
                  final haystack = [
                    item['public_reference'],
                    item['reservable_name'],
                    user['name'],
                  ].join(' ').toLowerCase();
                  return (_status == 'all' || status == _status) &&
                      haystack.contains(_query);
                }).toList();
                if (filtered.isEmpty) {
                  return const Center(
                    child: Text('No municipal spot reservations found.',
                        style: TextStyle(color: Color(0xFF94A3B8))),
                  );
                }
                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    return Card(
                      color: const Color(0xFF1C2541),
                      child: ListTile(
                        onTap: () => _showDetail(item, statuses),
                        leading: const Icon(Icons.event_note_rounded,
                            color: Color(0xFFF59E0B)),
                        title: Text(
                            item['reservable_name']?.toString() ??
                                'Destination',
                            style: const TextStyle(color: Colors.white)),
                        subtitle: Text(
                          '${item['public_reference'] ?? item['id']} · ${item['reservation_date'] ?? ''} · ${item['guests']} guests',
                          style: const TextStyle(color: Color(0xFFCBD5E1)),
                        ),
                        trailing: Text(_label(_statusName(item)),
                            style: const TextStyle(color: Color(0xFFF59E0B))),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _showDetail(Map<String, dynamic> reservation,
      List<Map<String, dynamic>> statuses) async {
    var selected = _statusName(reservation);
    final allowedTransitions =
        (reservation['allowed_transitions'] as List? ?? const [])
            .map((item) => item.toString())
            .toSet();
    final selectableStatuses = statuses
        .where((item) => allowedTransitions.contains(item['name']?.toString()))
        .toList(growable: false);
    final nextStatusId = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(
              reservation['public_reference']?.toString() ?? 'Reservation'),
          content: SizedBox(
            width: 440,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _row('Destination', reservation['reservable_name']),
              _row('Date', reservation['reservation_date']),
              _row('Time', reservation['start_time'] ?? 'Date only'),
              _row('Guests', reservation['guests']),
              _row('Notes', reservation['notes'] ?? 'None'),
              DropdownButtonFormField<String>(
                initialValue: null,
                decoration: InputDecoration(
                  labelText: selectableStatuses.isEmpty
                      ? 'No further status transitions'
                      : 'Next status',
                ),
                items: selectableStatuses
                    .map((item) => DropdownMenuItem(
                          value: item['name'].toString(),
                          child: Text(_label(item['name'].toString())),
                        ))
                    .toList(),
                onChanged: (value) =>
                    setState(() => selected = value ?? selected),
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Close')),
            FilledButton(
              onPressed: selectableStatuses.isEmpty ||
                      !allowedTransitions.contains(selected)
                  ? null
                  : () {
                      final match = selectableStatuses.where(
                          (item) => item['name']?.toString() == selected);
                      Navigator.pop(dialogContext,
                          match.isEmpty ? null : match.first['id']?.toString());
                    },
              child: const Text('Update Status'),
            ),
          ],
        ),
      ),
    );
    if (nextStatusId == null) return;
    try {
      await ref.read(lguRepositoryProvider).updateSpotReservationStatus(
            reservation['id'].toString(),
            nextStatusId,
          );
      if (!mounted) return;
      ref.invalidate(lguReservationsProvider);
      ref.invalidate(lguDashboardStatsProvider);
      ref.invalidate(lguActivityProvider);
      ref.invalidate(lguAnalyticsProvider);
      ref.invalidate(lguReportsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Reservation status updated.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Widget _row(String label, dynamic value) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 100, child: Text(label)),
          Expanded(child: Text(value?.toString() ?? '—')),
        ]),
      );

  String _statusName(Map<String, dynamic> item) => item['status'] is Map
      ? (item['status'] as Map)['name']?.toString() ?? 'pending'
      : item['status']?.toString() ?? 'pending';

  static String _label(String value) => value.isEmpty
      ? value
      : '${value[0].toUpperCase()}${value.substring(1).replaceAll('_', ' ')}';
}
