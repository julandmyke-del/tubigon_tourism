import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/lgu_providers.dart';

class LguAnalyticsPage extends ConsumerWidget {
  const LguAnalyticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analytics = ref.watch(lguAnalyticsProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF0B132B),
      body: analytics.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _State(
          message: 'Municipal analytics could not be loaded.',
          onRetry: () => ref.invalidate(lguAnalyticsProvider),
        ),
        data: (data) {
          final reservations = _map(data['reservationStatuses']);
          final waste = _map(data['wasteStatuses']);
          return RefreshIndicator(
            onRefresh: () => ref.refresh(lguAnalyticsProvider.future),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text('Municipal Analytics',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                const Text('Live counts from municipal workflow records.',
                    style: TextStyle(color: Color(0xFF94A3B8))),
                const SizedBox(height: 20),
                Wrap(spacing: 12, runSpacing: 12, children: [
                  _Metric('Reservations', data['totalReservations']),
                  _Metric('Verified MSMEs', data['verifiedMsmes']),
                  _Metric('MSMEs awaiting review', data['pendingMsmes']),
                ]),
                const SizedBox(height: 20),
                _Breakdown(title: 'Reservation statuses', values: reservations),
                const SizedBox(height: 14),
                _Breakdown(title: 'Waste report statuses', values: waste),
              ],
            ),
          );
        },
      ),
    );
  }

  static Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : const {};
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value);
  final String label;
  final dynamic value;
  @override
  Widget build(BuildContext context) => Container(
        width: 210,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF1C2541),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${value ?? 0}',
              style: const TextStyle(
                  color: Color(0xFFF97316),
                  fontSize: 28,
                  fontWeight: FontWeight.w800)),
          Text(label, style: const TextStyle(color: Color(0xFFCBD5E1))),
        ]),
      );
}

class _Breakdown extends StatelessWidget {
  const _Breakdown({required this.title, required this.values});
  final String title;
  final Map<String, dynamic> values;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: const Color(0xFF1C2541),
            borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          if (values.isEmpty)
            const Text('No records yet.',
                style: TextStyle(color: Color(0xFF94A3B8)))
          else
            ...values.entries.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    Expanded(
                        child: Text(entry.key.replaceAll('_', ' '),
                            style: const TextStyle(color: Color(0xFFCBD5E1)))),
                    Text('${entry.value}',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700)),
                  ]),
                )),
        ]),
      );
}

class _State extends StatelessWidget {
  const _State({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(message, style: const TextStyle(color: Colors.white)),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ]),
      );
}
