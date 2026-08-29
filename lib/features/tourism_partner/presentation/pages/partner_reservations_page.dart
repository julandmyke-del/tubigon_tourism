import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/tourism_partner_providers.dart';
import '../partner_theme.dart';

class PartnerReservationsPage extends ConsumerStatefulWidget {
  const PartnerReservationsPage({super.key});
  @override
  ConsumerState<PartnerReservationsPage> createState() => _State();
}

class _State extends ConsumerState<PartnerReservationsPage> {
  String _status = 'all';
  String? _busy;

  @override
  Widget build(BuildContext context) {
    final reservations = ref
        .watch(partnerReservationsProvider(_status == 'all' ? null : _status));
    return Scaffold(
      backgroundColor: PartnerTheme.bgDark,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Reservations', style: PartnerTheme.headingLarge()),
          Text(
              'Only reservations for your managed destinations and listings are shown.',
              style: PartnerTheme.label()),
          const SizedBox(height: 14),
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
                onSelected: (_) => setState(() => _status = value),
              ),
          ]),
          const SizedBox(height: 14),
          Expanded(
            child: reservations.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _Error(error.toString(),
                  () => ref.invalidate(partnerReservationsProvider)),
              data: (items) => items.isEmpty
                  ? const Center(
                      child: Text('No reservations yet.',
                          style: TextStyle(color: PartnerTheme.textMuted)))
                  : RefreshIndicator(
                      onRefresh: () async => ref.refresh(
                          partnerReservationsProvider(
                                  _status == 'all' ? null : _status)
                              .future),
                      child: ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) => _card(items[index]),
                      ),
                    ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _card(Map<String, dynamic> item) {
    final id = item['id']?.toString() ?? '';
    final status = item['status']?.toString() ?? 'pending';
    final allowed = switch (status) {
      'pending' => const ['confirmed', 'rejected', 'cancelled'],
      'approved' => const ['confirmed', 'completed', 'cancelled'],
      'confirmed' => const ['completed', 'cancelled'],
      _ => const <String>[],
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: PartnerTheme.cardDecoration(),
      child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          runSpacing: 10,
          children: [
            SizedBox(
                width: 470,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          item['listing_name']?.toString() ??
                              'Managed destination',
                          style: PartnerTheme.headingSmall()),
                      Text(
                          '${item['guest_name'] ?? 'Tourist'} • ${item['guests'] ?? 1} guest(s)',
                          style: PartnerTheme.label()),
                      Text('${item['date'] ?? ''} ${item['time'] ?? ''}',
                          style: PartnerTheme.label()),
                      Chip(label: Text(status.toUpperCase())),
                      if ((item['notes']?.toString() ?? '').isNotEmpty)
                        Text(item['notes'].toString(),
                            style:
                                const TextStyle(color: PartnerTheme.textMuted)),
                    ])),
            if (allowed.isNotEmpty)
              Wrap(
                  spacing: 8,
                  children: allowed
                      .map((next) => OutlinedButton(
                            onPressed:
                                _busy == id ? null : () => _update(id, next),
                            child: Text(next),
                          ))
                      .toList()),
          ]),
    );
  }

  Future<void> _update(String id, String status) async {
    setState(() => _busy = id);
    try {
      await ref
          .read(tourismPartnerRepositoryProvider)
          .updateReservationStatus(id, status);
      ref.invalidate(partnerReservationsProvider);
      ref.invalidate(partnerDashboardStatsProvider);
      if (mounted) _message('Reservation $status.');
    } catch (error) {
      if (mounted) _message(error.toString(), error: true);
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

class _Error extends StatelessWidget {
  const _Error(this.message, this.retry);
  final String message;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(message, style: const TextStyle(color: PartnerTheme.red)),
        OutlinedButton(onPressed: retry, child: const Text('Retry')),
      ]));
}
