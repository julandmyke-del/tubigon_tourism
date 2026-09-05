import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../providers/lgu_providers.dart';

class LguAnalyticsPage extends ConsumerWidget {
  const LguAnalyticsPage({super.key});
  static const _surface = Color(0xFF1C2541);
  static const _border = Color(0xFF334155);
  static const _accent = Color(0xFFF97316);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analytics = ref.watch(lguAnalyticsProvider);
    final period = ref.watch(lguAnalyticsPeriodProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF0B132B),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(lguAnalyticsProvider.future),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 12,
              children: [
                const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Municipal Tourism Analytics',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 25,
                              fontWeight: FontWeight.w800)),
                      Text(
                          'Authoritative aggregates calculated by Laravel/MySQL.',
                          style: TextStyle(color: AppColors.grey400)),
                    ]),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<String>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: 'today', label: Text('Today')),
                      ButtonSegment(value: 'weekly', label: Text('Week')),
                      ButtonSegment(value: 'monthly', label: Text('Month')),
                      ButtonSegment(value: 'quarterly', label: Text('Quarter')),
                      ButtonSegment(value: 'yearly', label: Text('Year')),
                      ButtonSegment(value: 'custom', label: Text('Custom')),
                    ],
                    selected: {period},
                    onSelectionChanged: (value) async {
                      final next = value.first;
                      if (next == 'custom') {
                        final selected = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (!context.mounted || selected == null) return;
                        if (selected.duration.inDays > 365) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Custom ranges may cover at most 366 days.')),
                          );
                          return;
                        }
                        final format = DateFormat('yyyy-MM-dd');
                        ref.read(lguAnalyticsDateRangeProvider.notifier).state =
                            LguDateRange(
                          format.format(selected.start),
                          format.format(selected.end),
                        );
                      } else {
                        ref.read(lguAnalyticsDateRangeProvider.notifier).state =
                            null;
                      }
                      ref.read(lguAnalyticsPeriodProvider.notifier).state =
                          next;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            analytics.when(
              loading: () => const _AnalyticsSkeleton(),
              error: (error, _) => _AnalyticsState(
                message: 'Municipal analytics could not be loaded.\n$error',
                retry: () => ref.invalidate(lguAnalyticsProvider),
              ),
              data: (data) => _analyticsContent(data),
            ),
          ],
        ),
      ),
    );
  }

  Widget _analyticsContent(Map<String, dynamic> data) {
    final reservationStatuses = _map(data['reservationStatuses']);
    final msmeStatuses = _map(data['msmeStatuses']);
    final wasteStatuses = _map(data['wasteStatuses']);
    final spotStatuses = _map(data['touristSpotStatuses']);
    final booking = _map(data['bookingOverview']);
    final series = _list(data['reservationsOverTime']);
    final mostBooked = _list(data['mostBookedDestinations']);
    final comparison = data['reservationChangePercent'];

    if (_int(data['totalReservations']) == 0 &&
        msmeStatuses.isEmpty &&
        wasteStatuses.isEmpty) {
      return const _AnalyticsState(
        message:
            'No operational records exist for this period. Try selecting a different date range.',
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 12, runSpacing: 12, children: [
        _Kpi('Reservations', _int(data['totalReservations']),
            icon: Icons.event_note_rounded,
            comparison: comparison == null
                ? null
                : '${comparison >= 0 ? '+' : ''}$comparison% vs previous period'),
        _Kpi('Verified MSMEs', _int(data['verifiedMsmes']),
            icon: Icons.verified_rounded),
        _Kpi('Active Tourist Spots', _int(data['activeTouristSpots']),
            icon: Icons.place_rounded),
        _Kpi('Resolved Waste Reports', _int(data['resolvedWasteReports']),
            icon: Icons.task_alt_rounded),
      ]),
      const SizedBox(height: 16),
      LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final trend = _AnalyticsPanel(
          title: 'Reservations Over Time',
          child: _MiniBarChart(values: series),
        );
        final status = _AnalyticsPanel(
          title: 'Reservation Status Breakdown',
          child: _Breakdown(values: reservationStatuses),
        );
        return wide
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 3, child: trend),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: status),
              ])
            : Column(children: [trend, const SizedBox(height: 12), status]);
      }),
      const SizedBox(height: 12),
      LayoutBuilder(builder: (context, constraints) {
        final cards = [
          _AnalyticsPanel(
              title: 'MSME Verification',
              child: _Breakdown(values: msmeStatuses)),
          _AnalyticsPanel(
              title: 'Waste Report Status',
              child: _Breakdown(values: wasteStatuses)),
          _AnalyticsPanel(
              title: 'Tourist Spot Status',
              child: _Breakdown(values: spotStatuses)),
          _AnalyticsPanel(
              title: 'Booking Availability',
              child: _Breakdown(values: booking)),
        ];
        if (constraints.maxWidth < 800) {
          return Column(
              children: cards
                  .expand((card) => [card, const SizedBox(height: 12)])
                  .toList());
        }
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 2.1,
          children: cards,
        );
      }),
      const SizedBox(height: 12),
      _AnalyticsPanel(
        title: 'Most Booked Destinations',
        child: mostBooked.isEmpty
            ? const Text('No destination reservations for this period.',
                style: TextStyle(color: AppColors.grey400))
            : Column(
                children: mostBooked
                    .asMap()
                    .entries
                    .map((entry) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: _accent.withValues(alpha: .14),
                            child: Text('${entry.key + 1}',
                                style: const TextStyle(color: _accent)),
                          ),
                          title: Text(
                              entry.value['name']?.toString() ?? 'Destination',
                              style: const TextStyle(color: Colors.white)),
                          trailing: Text(
                              '${entry.value['total'] ?? 0} reservation(s)',
                              style: const TextStyle(color: AppColors.grey400)),
                        ))
                    .toList(),
              ),
      ),
    ]);
  }

  static int _int(dynamic value) => int.tryParse('$value') ?? 0;
  static Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : const {};
  static List<Map<String, dynamic>> _list(dynamic value) => value is List
      ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : const [];
}

class _Kpi extends StatelessWidget {
  const _Kpi(this.label, this.value, {required this.icon, this.comparison});
  final String label;
  final int value;
  final IconData icon;
  final String? comparison;
  @override
  Widget build(BuildContext context) => Container(
        width: 245,
        constraints: const BoxConstraints(minHeight: 120),
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: LguAnalyticsPage._surface,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: LguAnalyticsPage._border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: LguAnalyticsPage._accent),
          const SizedBox(height: 8),
          Text('$value',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 27,
                  fontWeight: FontWeight.w800)),
          Text(label, style: const TextStyle(color: AppColors.grey400)),
          if (comparison != null)
            Text(comparison!,
                style: const TextStyle(color: AppColors.grey500, fontSize: 11)),
        ]),
      );
}

class _AnalyticsPanel extends StatelessWidget {
  const _AnalyticsPanel({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: LguAnalyticsPage._surface,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: LguAnalyticsPage._border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          child,
        ]),
      );
}

class _Breakdown extends StatelessWidget {
  const _Breakdown({required this.values});
  final Map<String, dynamic> values;
  @override
  Widget build(BuildContext context) {
    final total = values.values
        .fold<int>(0, (sum, value) => sum + (int.tryParse('$value') ?? 0));
    if (values.isEmpty || total == 0) {
      return const Text('No records for this period.',
          style: TextStyle(color: AppColors.grey400));
    }
    return Column(
        children: values.entries.map((entry) {
      final count = int.tryParse('${entry.value}') ?? 0;
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(children: [
          Row(children: [
            Expanded(
                child: Text(_label(entry.key),
                    style: const TextStyle(color: AppColors.grey300))),
            Text('$count',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              minHeight: 6,
              value: count / total,
              backgroundColor: const Color(0xFF334155),
              color: LguAnalyticsPage._accent,
            ),
          ),
        ]),
      );
    }).toList());
  }

  static String _label(String value) => value
      .split('_')
      .map((part) =>
          part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

class _MiniBarChart extends StatelessWidget {
  const _MiniBarChart({required this.values});
  final List<Map<String, dynamic>> values;
  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return const SizedBox(
          height: 160,
          child: Center(
              child: Text('No reservation records for this period.',
                  style: TextStyle(color: AppColors.grey400))));
    }
    final maxValue = values
        .map((e) => int.tryParse('${e['total']}') ?? 0)
        .fold<int>(1, (a, b) => a > b ? a : b);
    return SizedBox(
      height: 190,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: values.take(31).map((item) {
          final value = int.tryParse('${item['total']}') ?? 0;
          return Expanded(
            child: Tooltip(
              message: '${item['date']}: $value reservation(s)',
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child:
                    Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Text('$value',
                      style: const TextStyle(
                          color: AppColors.grey400, fontSize: 9)),
                  const SizedBox(height: 3),
                  Container(
                    height: 130 * (value / maxValue),
                    constraints: const BoxConstraints(minHeight: 4),
                    decoration: const BoxDecoration(
                      color: LguAnalyticsPage._accent,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                  ),
                ]),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _AnalyticsState extends StatelessWidget {
  const _AnalyticsState({required this.message, this.retry});
  final String message;
  final VoidCallback? retry;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(36),
        decoration: BoxDecoration(
            color: LguAnalyticsPage._surface,
            borderRadius: BorderRadius.circular(15)),
        child: Column(children: [
          const Icon(Icons.query_stats_rounded,
              color: AppColors.grey500, size: 42),
          const SizedBox(height: 10),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.grey400)),
          if (retry != null)
            TextButton.icon(
                onPressed: retry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry')),
        ]),
      );
}

class _AnalyticsSkeleton extends StatelessWidget {
  const _AnalyticsSkeleton();
  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 12,
        runSpacing: 12,
        children: List.generate(
            6,
            (_) => Container(
                  width: 245,
                  height: 130,
                  decoration: BoxDecoration(
                      color: LguAnalyticsPage._surface,
                      borderRadius: BorderRadius.circular(15)),
                )),
      );
}
