import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../providers/msme_portal_providers.dart';
import '../msme_theme.dart';
import '../widgets/msme_portal_states.dart';

class MsmePortalAnalyticsPage extends ConsumerWidget {
  const MsmePortalAnalyticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(currentMsmeProvider);
    final analytics = ref.watch(msmePortalAnalyticsProvider);
    final selectedPeriod = ref.watch(msmeAnalyticsPeriodProvider);

    if (current.isLoading) {
      return const Scaffold(
          backgroundColor: MsmeTheme.bgDark,
          body: Center(child: CircularProgressIndicator()));
    }
    if (current.hasError) {
      return Scaffold(
        backgroundColor: MsmeTheme.bgDark,
        body: MsmePortalErrorState(
          message: friendlyMsmeError(
              current.error!, 'We couldn’t load your business account.'),
          onRetry: () => ref.invalidate(currentMsmeProvider),
        ),
      );
    }
    if (current.valueOrNull?.hasBusiness != true) {
      return const Scaffold(
        backgroundColor: MsmeTheme.bgDark,
        body: MsmeSetupRequired(
          title: 'No analytics available yet',
          message:
              'Complete your business setup. Reservation and review performance will appear here as customers interact with your business.',
        ),
      );
    }

    return Scaffold(
      backgroundColor: MsmeTheme.bgDark,
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 12,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Business Analytics', style: MsmeTheme.headingLarge()),
                const Text(
                    'Owner-scoped reservation and review performance from Laravel/MySQL.',
                    style: TextStyle(color: MsmeTheme.textMuted)),
              ]),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  initialValue: selectedPeriod,
                  decoration: const InputDecoration(labelText: 'Time range'),
                  items: const [
                    DropdownMenuItem(
                        value: '7_days', child: Text('Last 7 Days')),
                    DropdownMenuItem(
                        value: '30_days', child: Text('Last 30 Days')),
                    DropdownMenuItem(
                        value: '3_months', child: Text('Last 3 Months')),
                    DropdownMenuItem(value: 'year', child: Text('This Year')),
                    DropdownMenuItem(
                        value: 'custom', child: Text('Custom Range')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    if (value == 'custom') {
                      _selectCustomRange(context, ref);
                    } else {
                      ref.read(msmeAnalyticsRangeProvider.notifier).state =
                          null;
                      ref.read(msmeAnalyticsPeriodProvider.notifier).state =
                          value;
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          analytics.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(60),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => SizedBox(
              height: 300,
              child: MsmePortalErrorState(
                message: friendlyMsmeError(
                    error, 'We couldn’t load your business analytics.'),
                onRetry: () => ref.invalidate(msmePortalAnalyticsProvider),
              ),
            ),
            data: _content,
          ),
        ],
      ),
    );
  }

  Future<void> _selectCustomRange(BuildContext context, WidgetRef ref) async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (!context.mounted || range == null) return;
    if (range.duration.inDays > 365) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Custom analytics ranges may cover at most 366 days.')));
      return;
    }
    final format = DateFormat('yyyy-MM-dd');
    ref.read(msmeAnalyticsRangeProvider.notifier).state = MsmeAnalyticsRange(
        format.format(range.start), format.format(range.end));
    ref.read(msmeAnalyticsPeriodProvider.notifier).state = 'custom';
  }

  Widget _content(Map<String, dynamic> data) {
    final trend = (data['reservationTrend'] as List? ?? const [])
        .whereType<Map>()
        .toList(growable: false);
    final statuses = _map(data['reservationStatuses']);
    final ratings = _map(data['ratingDistribution']);
    final total = (data['totalReservations'] as num?)?.toInt() ?? 0;
    final reviews = (data['reviewCount'] as num?)?.toInt() ?? 0;
    final comparison = data['reservationComparisonPercent'] as num?;
    if (total == 0 && reviews == 0) {
      return const _EmptyAnalytics();
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 12, runSpacing: 12, children: [
        _Metric('Reservations', total, Icons.calendar_month_rounded,
            detail: comparison == null
                ? 'No previous-period comparison'
                : '${comparison >= 0 ? '+' : ''}${comparison.toStringAsFixed(1)}% vs previous period'),
        _Metric('Pending', data['pendingReservations'] ?? 0,
            Icons.pending_actions_rounded),
        _Metric('Confirmed', data['confirmedReservations'] ?? 0,
            Icons.event_available_rounded),
        _Metric('Completed', data['completedReservations'] ?? 0,
            Icons.task_alt_rounded),
        _Metric('Cancelled', data['cancelledReservations'] ?? 0,
            Icons.event_busy_rounded),
        _Metric(
            'Average Rating', data['averageRating'] ?? 0, Icons.star_rounded,
            detail: '$reviews customer reviews'),
      ]),
      const SizedBox(height: 18),
      LayoutBuilder(builder: (context, constraints) {
        final width = constraints.maxWidth >= 850
            ? (constraints.maxWidth - 12) / 2
            : constraints.maxWidth;
        return Wrap(spacing: 12, runSpacing: 12, children: [
          SizedBox(
              width: width,
              child: _Breakdown(
                  title: 'Reservation Status Breakdown', values: statuses)),
          SizedBox(
              width: width,
              child: _Breakdown(
                  title: 'Rating Distribution', values: ratings, stars: true)),
        ]);
      }),
      const SizedBox(height: 18),
      _Trend(values: trend),
    ]);
  }

  static Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : const {};
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.icon, {this.detail});
  final String label;
  final Object value;
  final IconData icon;
  final String? detail;

  @override
  Widget build(BuildContext context) => Container(
        width: 230,
        constraints: const BoxConstraints(minHeight: 122),
        padding: const EdgeInsets.all(18),
        decoration: MsmeTheme.cardDecoration(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: MsmeTheme.primaryOrange),
          const SizedBox(height: 10),
          Text('$value',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(color: MsmeTheme.textMuted)),
          if (detail != null) ...[
            const SizedBox(height: 5),
            Text(detail!,
                style: const TextStyle(
                    color: MsmeTheme.textDisabled, fontSize: 11)),
          ],
        ]),
      );
}

class _Breakdown extends StatelessWidget {
  const _Breakdown(
      {required this.title, required this.values, this.stars = false});
  final String title;
  final Map<String, dynamic> values;
  final bool stars;

  @override
  Widget build(BuildContext context) {
    final maximum = values.values
        .whereType<num>()
        .fold<num>(0, (highest, value) => value > highest ? value : highest);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: MsmeTheme.cardDecoration(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: MsmeTheme.headingSmall()),
        const SizedBox(height: 14),
        if (values.isEmpty)
          const Text('No records for this period.',
              style: TextStyle(color: MsmeTheme.textMuted))
        else
          ...values.entries.map((entry) {
            final number = (entry.value as num?)?.toDouble() ?? 0;
            final fraction = maximum == 0 ? 0.0 : number / maximum;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                SizedBox(
                    width: 95,
                    child: Text(stars ? '${entry.key} Star' : _label(entry.key),
                        style: const TextStyle(color: MsmeTheme.textMuted))),
                Expanded(
                    child: LinearProgressIndicator(
                  value: fraction,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(8),
                  color: MsmeTheme.primaryOrange,
                  backgroundColor: MsmeTheme.surfaceDark,
                )),
                const SizedBox(width: 10),
                SizedBox(
                    width: 30,
                    child: Text('${number.toInt()}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(color: Colors.white))),
              ]),
            );
          }),
      ]),
    );
  }

  static String _label(String value) => value
      .split('_')
      .map((part) =>
          part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

class _Trend extends StatelessWidget {
  const _Trend({required this.values});
  final List<Map> values;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: MsmeTheme.cardDecoration(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Reservation Trend', style: MsmeTheme.headingSmall()),
          const SizedBox(height: 14),
          if (values.isEmpty)
            const Text('No reservation activity in this period.',
                style: TextStyle(color: MsmeTheme.textMuted))
          else
            SizedBox(
              height: 150,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: values.take(31).map((entry) {
                  final count = (entry['total'] as num?)?.toDouble() ?? 0;
                  final max = values
                      .map((item) => (item['total'] as num?)?.toDouble() ?? 0)
                      .fold<double>(1, (a, b) => b > a ? b : a);
                  return Expanded(
                    child: Tooltip(
                      message:
                          '${entry['date']}: ${count.toInt()} reservations',
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Container(
                          height: 12 + (count / max) * 120,
                          decoration: const BoxDecoration(
                            color: MsmeTheme.primaryOrange,
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(5),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
        ]),
      );
}

class _EmptyAnalytics extends StatelessWidget {
  const _EmptyAnalytics();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(40),
        decoration: MsmeTheme.cardDecoration(),
        child: const Column(children: [
          Icon(Icons.insights_rounded,
              size: 46, color: MsmeTheme.primaryOrange),
          SizedBox(height: 12),
          Text('No analytics available yet',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text(
              'Reservation and review activity will appear as customers interact with your business.',
              textAlign: TextAlign.center,
              style: TextStyle(color: MsmeTheme.textMuted)),
        ]),
      );
}
