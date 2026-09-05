import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../providers/lgu_providers.dart';

class LguReportsPage extends ConsumerWidget {
  const LguReportsPage({super.key});
  static const _surface = Color(0xFF1C2541);
  static const _border = Color(0xFF334155);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(lguReportPeriodProvider);
    final category = ref.watch(lguReportCategoryProvider);
    final report = ref.watch(lguReportsProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF0B132B),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('Reports & Statistics',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.w800)),
          const Text(
              'Official municipal operational summaries generated from authoritative records.',
              style: TextStyle(color: AppColors.grey400)),
          const SizedBox(height: 16),
          Wrap(spacing: 12, runSpacing: 12, children: [
            _selector(
              label: 'Reporting period',
              value: period,
              values: const [
                'daily',
                'weekly',
                'monthly',
                'quarterly',
                'yearly',
                'custom',
              ],
              onChanged: (value) {
                if (value == 'custom') {
                  _selectCustomRange(context, ref);
                } else {
                  ref.read(lguReportDateRangeProvider.notifier).state = null;
                  ref.read(lguReportPeriodProvider.notifier).state = value;
                }
              },
            ),
            _selector(
              label: 'Report category',
              value: category,
              values: const [
                'tourism_operations',
                'reservations',
                'tourist_spots',
                'msmes',
                'waste_reports',
                'emergency_contacts',
                'announcements',
              ],
              onChanged: (value) =>
                  ref.read(lguReportCategoryProvider.notifier).state = value,
            ),
            IconButton.filledTonal(
              tooltip: 'Refresh report',
              onPressed: () => ref.invalidate(lguReportsProvider),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ]),
          const SizedBox(height: 18),
          report.when(
            loading: () => const Center(
                child: Padding(
                    padding: EdgeInsets.all(48),
                    child: CircularProgressIndicator())),
            error: (error, _) => _ReportState(
              message: 'The report could not be generated.\n$error',
              retry: () => ref.invalidate(lguReportsProvider),
            ),
            data: (data) => SelectionArea(child: _report(data)),
          ),
          const SizedBox(height: 12),
          const Text(
            'PDF and CSV export infrastructure is not configured, so no non-functional download action is shown. This report remains selectable and browser-printable.',
            style: TextStyle(color: AppColors.grey500, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _report(Map<String, dynamic> data) {
    final summary = _map(data['summary']);
    final period = _map(data['period']);
    final generated = DateTime.tryParse(data['generatedAt']?.toString() ?? '');
    final insights = (data['keyInsights'] as List? ?? const [])
        .map((e) => e.toString())
        .toList();
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.account_balance_rounded,
              color: Color(0xFFF97316), size: 30),
          SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('TUBIGON TOURISM OFFICE',
                    style: TextStyle(
                        color: Color(0xFFF97316),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1)),
                Text('Municipal Operations Report',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800)),
              ])),
        ]),
        const Divider(height: 30, color: _border),
        Wrap(spacing: 28, runSpacing: 8, children: [
          _meta('Category',
              _label(data['category']?.toString() ?? 'tourism_operations')),
          _meta('Period', '${period['from'] ?? '—'} to ${period['to'] ?? '—'}'),
          _meta('Generated by', data['generatedBy']?.toString() ?? 'LGU Staff'),
          _meta(
              'Generated at',
              generated == null
                  ? '—'
                  : DateFormat('MMM d, yyyy h:mm a')
                      .format(generated.toLocal())),
        ]),
        const SizedBox(height: 24),
        const Text('Summary KPIs',
            style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Wrap(
            spacing: 10,
            runSpacing: 10,
            children: summary.entries
                .map((entry) => Container(
                      width: 190,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                          color: const Color(0xFF111C36),
                          borderRadius: BorderRadius.circular(12)),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${entry.value ?? 0}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 23,
                                    fontWeight: FontWeight.w800)),
                            Text(_label(entry.key),
                                style: const TextStyle(
                                    color: AppColors.grey400, fontSize: 12)),
                          ]),
                    ))
                .toList()),
        const SizedBox(height: 22),
        LayoutBuilder(builder: (context, constraints) {
          final sections = [
            ('Reservation Status', _map(data['reservationStatuses'])),
            ('MSME Verification', _map(data['msmeStatuses'])),
            ('Waste Report Status', _map(data['wasteStatuses'])),
            ('Tourist Spot Status', _map(data['touristSpotStatuses'])),
            ('Booking Availability', _map(data['bookingOverview'])),
          ];
          if (constraints.maxWidth < 760) {
            return Column(
                children: sections
                    .expand((section) => [
                          _Breakdown(title: section.$1, values: section.$2),
                          const SizedBox(height: 10),
                        ])
                    .toList());
          }
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: sections
                .map((section) => SizedBox(
                      width: (constraints.maxWidth - 10) / 2,
                      child: _Breakdown(title: section.$1, values: section.$2),
                    ))
                .toList(),
          );
        }),
        if (insights.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text('Key Operational Insights',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ...insights.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                          padding: EdgeInsets.only(top: 3),
                          child: Icon(Icons.arrow_right_rounded,
                              color: Color(0xFFF97316))),
                      Expanded(
                          child: Text(item,
                              style:
                                  const TextStyle(color: AppColors.grey300))),
                    ]),
              )),
        ],
      ]),
    );
  }

  Future<void> _selectCustomRange(BuildContext context, WidgetRef ref) async {
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (!context.mounted || selected == null) return;
    if (selected.duration.inDays > 365) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Custom ranges may cover at most 366 days.')));
      return;
    }
    final format = DateFormat('yyyy-MM-dd');
    ref.read(lguReportDateRangeProvider.notifier).state = LguDateRange(
      format.format(selected.start),
      format.format(selected.end),
    );
    ref.read(lguReportPeriodProvider.notifier).state = 'custom';
  }

  Widget _selector(
          {required String label,
          required String value,
          required List<String> values,
          required ValueChanged<String> onChanged}) =>
      SizedBox(
        width: 245,
        child: DropdownButtonFormField<String>(
          initialValue: value,
          decoration: InputDecoration(labelText: label),
          items: values
              .map((item) =>
                  DropdownMenuItem(value: item, child: Text(_label(item))))
              .toList(),
          onChanged: (next) {
            if (next != null) onChanged(next);
          },
        ),
      );

  static Widget _meta(String label, String value) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(color: AppColors.grey500, fontSize: 11)),
        Text(value,
            style: const TextStyle(
                color: AppColors.grey300, fontWeight: FontWeight.w600)),
      ]);

  static Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : const {};
  static String _label(String value) => value
      .split('_')
      .map((part) =>
          part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

class _Breakdown extends StatelessWidget {
  const _Breakdown({required this.title, required this.values});
  final String title;
  final Map<String, dynamic> values;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: const Color(0xFF111C36),
            borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (values.isEmpty)
            const Text('No records for this period.',
                style: TextStyle(color: AppColors.grey500))
          else
            ...values.entries.map((entry) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    Expanded(
                        child: Text(LguReportsPage._label(entry.key),
                            style: const TextStyle(color: AppColors.grey400))),
                    Text('${entry.value}',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700)),
                  ]),
                )),
        ]),
      );
}

class _ReportState extends StatelessWidget {
  const _ReportState({required this.message, required this.retry});
  final String message;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(36),
        decoration: BoxDecoration(
            color: LguReportsPage._surface,
            borderRadius: BorderRadius.circular(15)),
        child: Column(children: [
          const Icon(Icons.description_outlined,
              color: AppColors.grey500, size: 42),
          const SizedBox(height: 8),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.grey400)),
          TextButton.icon(
              onPressed: retry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry')),
        ]),
      );
}
