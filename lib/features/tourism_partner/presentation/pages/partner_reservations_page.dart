import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/exceptions/app_exception.dart';
import '../../../connected_operations/presentation/reservation_conversation.dart';

import '../../providers/tourism_partner_providers.dart';
import '../partner_theme.dart';

class PartnerReservationsPage extends ConsumerStatefulWidget {
  const PartnerReservationsPage({super.key});

  @override
  ConsumerState<PartnerReservationsPage> createState() =>
      _PartnerReservationsState();
}

class _PartnerReservationsState extends ConsumerState<PartnerReservationsPage> {
  final _search = TextEditingController();
  String _status = 'all';
  String? _scope;
  String _sort = 'visit_asc';
  String _submittedSearch = '';
  String? _busy;

  PartnerReservationQuery get _query => PartnerReservationQuery(
        status: _status == 'all' ? null : _status,
        search: _submittedSearch,
        scope: _scope,
        sort: _sort,
      );

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final queue = ref.watch(partnerReservationQueueProvider(_query));
    final compact = MediaQuery.sizeOf(context).width < 700;
    return Scaffold(
      backgroundColor: PartnerTheme.bgDark,
      body: Padding(
        padding: EdgeInsets.all(compact ? 16 : 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Reservation Operations', style: PartnerTheme.headingLarge()),
          Text(
              'Only bookings for your currently assigned destination are operational here.',
              style: PartnerTheme.label()),
          const SizedBox(height: 16),
          _filters(compact),
          const SizedBox(height: 14),
          Expanded(
            child: queue.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => _ErrorState(
                  onRetry: () =>
                      ref.invalidate(partnerReservationQueueProvider(_query))),
              data: (data) {
                final items = (data['items'] as List? ?? const [])
                    .whereType<Map>()
                    .map((item) => Map<String, dynamic>.from(item))
                    .toList();
                final summary = data['summary'] is Map
                    ? Map<String, dynamic>.from(data['summary'] as Map)
                    : <String, dynamic>{};
                return RefreshIndicator(
                  onRefresh: () async => ref
                      .refresh(partnerReservationQueueProvider(_query).future),
                  child: ListView(children: [
                    _Summary(summary: summary),
                    const SizedBox(height: 14),
                    if (items.isEmpty)
                      const _EmptyState()
                    else
                      ...items.map((item) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _ReservationCard(
                              item: item,
                              busy: _busy == item['id']?.toString(),
                              onOpen: () => _openDetail(item['id'].toString()),
                              onTransition: (status) =>
                                  _update(item['id'].toString(), status),
                            ),
                          )),
                  ]),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  Widget _filters(bool compact) {
    final search = TextField(
      controller: _search,
      onSubmitted: (_) =>
          setState(() => _submittedSearch = _search.text.trim()),
      decoration: InputDecoration(
        hintText: 'Booking reference or Tourist name',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: IconButton(
          tooltip: 'Search reservations',
          onPressed: () =>
              setState(() => _submittedSearch = _search.text.trim()),
          icon: const Icon(Icons.arrow_forward_rounded),
        ),
      ),
    );
    final controls = Wrap(spacing: 8, runSpacing: 8, children: [
      DropdownButton<String>(
        value: _scope,
        hint: const Text('All visit dates'),
        items: const [
          DropdownMenuItem(value: null, child: Text('All visit dates')),
          DropdownMenuItem(value: 'today', child: Text('Today')),
          DropdownMenuItem(value: 'upcoming', child: Text('Upcoming')),
        ],
        onChanged: (value) => setState(() => _scope = value),
      ),
      DropdownButton<String>(
        value: _sort,
        items: const [
          DropdownMenuItem(
              value: 'visit_asc', child: Text('Visit date ascending')),
          DropdownMenuItem(
              value: 'visit_desc', child: Text('Visit date descending')),
          DropdownMenuItem(value: 'newest', child: Text('Newest request')),
        ],
        onChanged: (value) => setState(() => _sort = value!),
      ),
    ]);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (compact) search else SizedBox(width: 430, child: search),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final value in const [
          'all',
          'pending',
          'confirmed',
          'completed',
          'cancelled',
          'rejected'
        ])
          ChoiceChip(
              label: Text(value),
              selected: _status == value,
              onSelected: (_) => setState(() => _status = value)),
      ]),
      const SizedBox(height: 8),
      controls,
    ]);
  }

  Future<void> _openDetail(String id) async {
    final repository = ref.read(tourismPartnerRepositoryProvider);
    try {
      final item = await repository.getReservationById(id);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('${item['public_reference'] ?? 'Reservation Details'}'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _detail('Tourist', item['guest_name']),
                    _detail(
                        'Phone',
                        item['customer'] is Map
                            ? (item['customer'] as Map)['phone']
                            : null),
                    _detail(
                        'Email',
                        item['customer'] is Map
                            ? (item['customer'] as Map)['email']
                            : null),
                    _detail('Destination', item['listing_name']),
                    _detail('Visit date', item['date']),
                    _detail('Time', item['time']),
                    _detail('Guests', item['guests']),
                    _detail('Status', item['status']),
                    _detail('Special request', item['notes']),
                    if (item['items'] is List) ...[
                      const Divider(height: 28),
                      Text('Booking Items', style: PartnerTheme.headingSmall()),
                      for (final line
                          in (item['items'] as List).whereType<Map>())
                        ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                                line['offering_name_snapshot']?.toString() ??
                                    'Offering'),
                            subtitle: Text(
                                '${line['quantity']} × ₱${line['unit_price_snapshot']}'),
                            trailing: Text('₱${line['subtotal']}')),
                    ],
                    const Divider(height: 28),
                    Text('Status History', style: PartnerTheme.headingSmall()),
                    const SizedBox(height: 8),
                    for (final event
                        in (item['status_history'] as List? ?? const [])
                            .whereType<Map>())
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.check_circle_outline_rounded),
                        title: Text(
                            '${event['status'] is Map ? (event['status'] as Map)['name'] : 'Updated'}'),
                        subtitle: Text(
                            '${event['notes'] ?? ''}\n${event['created_at'] ?? ''}'),
                      ),
                    const Divider(height: 28),
                    ReservationConversation(reservationId: id, partner: true),
                  ]),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'))
          ],
        ),
      );
    } catch (_) {
      if (mounted) _message("We couldn't load this reservation.", error: true);
    }
  }

  Widget _detail(String label, Object? value) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 130, child: Text(label, style: PartnerTheme.label())),
          Expanded(child: Text('${value ?? '—'}')),
        ]),
      );

  Future<void> _update(String id, String status) async {
    String? reason;
    if (status == 'rejected') {
      final controller = TextEditingController();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Reject reservation?'),
          content: TextField(
              controller: controller,
              maxLength: 1000,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Reason required')),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () =>
                    Navigator.pop(context, controller.text.trim().isNotEmpty),
                child: const Text('Reject')),
          ],
        ),
      );
      reason = controller.text.trim();
      controller.dispose();
      if (confirmed != true || !mounted) return;
    }
    final repository = ref.read(tourismPartnerRepositoryProvider);
    setState(() => _busy = id);
    try {
      await repository.updateReservationStatus(id, status, reason: reason);
      if (!mounted) return;
      ref.invalidate(partnerReservationQueueProvider);
      ref.invalidate(partnerReservationsProvider);
      ref.invalidate(partnerDashboardStatsProvider);
      ref.invalidate(partnerAnalyticsProvider);
      ref.invalidate(partnerNotificationsProvider);
      _message('Reservation $status.');
    } catch (error) {
      if (mounted) {
        ref.invalidate(partnerReservationQueueProvider);
        ref.invalidate(partnerReservationsProvider);
        _message(
          error is ConflictException
              ? 'This reservation was updated in another session. The latest status has been loaded.'
              : "We couldn't update this reservation.",
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  void _message(String text, {bool error = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            backgroundColor: error ? PartnerTheme.red : PartnerTheme.green,
            content: Text(text)),
      );
}

class _Summary extends StatelessWidget {
  const _Summary({required this.summary});
  final Map<String, dynamic> summary;
  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          'total',
          'pending',
          'confirmed',
          'completed',
          'cancelled',
          'rejected'
        ]
            .map((key) => Container(
                  width: 130,
                  padding: const EdgeInsets.all(12),
                  decoration: PartnerTheme.cardDecoration(),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${summary[key] ?? 0}',
                            style: PartnerTheme.headingSmall()),
                        Text(key[0].toUpperCase() + key.substring(1),
                            style: PartnerTheme.label()),
                      ]),
                ))
            .toList(),
      );
}

class _ReservationCard extends StatelessWidget {
  const _ReservationCard(
      {required this.item,
      required this.busy,
      required this.onOpen,
      required this.onTransition});
  final Map<String, dynamic> item;
  final bool busy;
  final VoidCallback onOpen;
  final ValueChanged<String> onTransition;
  @override
  Widget build(BuildContext context) {
    final allowed = (item['allowed_transitions'] as List? ?? const [])
        .map((value) => value.toString())
        .where(
            (value) => ['confirmed', 'rejected', 'completed'].contains(value))
        .toList();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: PartnerTheme.cardDecoration(),
          child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              runSpacing: 10,
              children: [
                SizedBox(
                    width: 500,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${item['public_reference'] ?? 'Reservation'}',
                              style: PartnerTheme.headingSmall()),
                          Text(
                              '${item['listing_name'] ?? 'Assigned destination'}',
                              style: const TextStyle(
                                  color: PartnerTheme.primaryOrange)),
                          Text(
                              '${item['guest_name'] ?? 'Tourist'} • ${item['guests'] ?? 1} guest(s)',
                              style: PartnerTheme.label()),
                          Text('${item['date'] ?? ''} ${item['time'] ?? ''}',
                              style: PartnerTheme.label()),
                          const SizedBox(height: 6),
                          Chip(
                              label: Text('${item['status'] ?? 'pending'}'
                                  .toUpperCase())),
                        ])),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  OutlinedButton.icon(
                      onPressed: busy ? null : onOpen,
                      icon: const Icon(Icons.visibility_outlined),
                      label: const Text('Details')),
                  for (final status in allowed)
                    FilledButton(
                        onPressed: busy ? null : () => onTransition(status),
                        child: Text(switch (status) {
                          'confirmed' => 'Confirm',
                          'rejected' => 'Reject',
                          'completed' => 'Mark Completed',
                          _ => status,
                        })),
                ]),
              ]),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
        decoration: PartnerTheme.cardDecoration(),
        child: Column(children: [
          Icon(Icons.event_note_outlined,
              size: 48, color: PartnerTheme.textMuted),
          const SizedBox(height: 12),
          Text('No reservations yet', style: PartnerTheme.headingSmall()),
          Text(
              'New Tourist reservations for your managed destination will appear here.',
              textAlign: TextAlign.center,
              style: PartnerTheme.label()),
        ]),
      );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text("We couldn't load your reservations."),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
      ]));
}
