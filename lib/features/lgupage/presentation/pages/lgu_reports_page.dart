import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/lgu_providers.dart';

class LguReportsPage extends ConsumerWidget {
  const LguReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(lguReportPeriodProvider);
    final report = ref.watch(lguReportsProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF0B132B),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Municipal Operations Report',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          DropdownButton<String>(
            value: period,
            dropdownColor: const Color(0xFF1C2541),
            style: const TextStyle(color: Colors.white),
            items: const ['daily', 'weekly', 'monthly', 'yearly']
                .map((value) => DropdownMenuItem(
                    value: value, child: Text(value.toUpperCase())))
                .toList(),
            onChanged: (value) {
              if (value != null) {
                ref.read(lguReportPeriodProvider.notifier).state = value;
              }
            },
          ),
          const SizedBox(height: 16),
          report.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => OutlinedButton.icon(
              onPressed: () => ref.invalidate(lguReportsProvider),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry report'),
            ),
            data: (data) => Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                  color: const Color(0xFF1C2541),
                  borderRadius: BorderRadius.circular(14)),
              child: Column(children: [
                _Row('Active tourist spots', data['spotsActive']),
                _Row('Verified MSMEs', data['msmesVerified']),
                _Row('Resolved waste reports', data['wasteReportsResolved']),
                _Row('Reservations', data['reservations']),
                const Divider(color: Color(0xFF334155)),
                _Row('Generated', data['generatedAt'] ?? '—'),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'These figures are live operational totals. File export is not enabled, so no download action is shown.',
            style: TextStyle(color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);
  final String label;
  final dynamic value;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(children: [
          Expanded(
              child: Text(label,
                  style: const TextStyle(color: Color(0xFFCBD5E1)))),
          Flexible(
              child: Text('${value ?? 0}',
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700))),
        ]),
      );
}
