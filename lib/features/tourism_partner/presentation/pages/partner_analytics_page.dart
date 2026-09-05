import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/tourism_partner_providers.dart';
import '../partner_theme.dart';

class PartnerAnalyticsPage extends ConsumerWidget {
  const PartnerAnalyticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analytics = ref.watch(partnerAnalyticsProvider);
    final period = ref.watch(partnerAnalyticsPeriodProvider);
    return Scaffold(
      backgroundColor: PartnerTheme.bgDark,
      body: Padding(
        padding:
            EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 16 : 24),
        child: analytics.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Center(
              child: OutlinedButton(
            onPressed: () => ref.invalidate(partnerAnalyticsProvider),
            child: const Text("We couldn't load analytics. Retry"),
          )),
          data: (data) {
            final statuses = data['statusDistribution'] is Map
                ? Map<String, dynamic>.from(data['statusDistribution'] as Map)
                : <String, dynamic>{};
            final ratings = data['ratingDistribution'] is Map
                ? Map<String, dynamic>.from(data['ratingDistribution'] as Map)
                : <String, dynamic>{};
            final total = (data['totalReservations'] as num?)?.toInt() ?? 0;
            return ListView(children: [
              Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  runSpacing: 10,
                  children: [
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Destination Performance',
                              style: PartnerTheme.headingLarge()),
                          Text(
                              'Authoritative reservation and review metrics for your assignment.',
                              style: PartnerTheme.label()),
                        ]),
                    DropdownButton<String>(
                      value: period,
                      items: const [
                        DropdownMenuItem(
                            value: '7_days', child: Text('Last 7 Days')),
                        DropdownMenuItem(
                            value: '30_days', child: Text('Last 30 Days')),
                        DropdownMenuItem(
                            value: '3_months', child: Text('Last 3 Months')),
                        DropdownMenuItem(
                            value: 'this_year', child: Text('This Year')),
                      ],
                      onChanged: (value) => ref
                          .read(partnerAnalyticsPeriodProvider.notifier)
                          .state = value!,
                    ),
                  ]),
              const SizedBox(height: 18),
              Wrap(spacing: 12, runSpacing: 12, children: [
                _Metric('Total Reservations', total, Icons.event_note_outlined),
                _Metric('Pending', statuses['pending'] ?? 0,
                    Icons.pending_actions_outlined),
                _Metric(
                    'Confirmed',
                    ((statuses['confirmed'] as num?) ?? 0) +
                        ((statuses['approved'] as num?) ?? 0),
                    Icons.event_available_outlined),
                _Metric('Completed', statuses['completed'] ?? 0,
                    Icons.task_alt_outlined),
                _Metric('Average Rating', data['averageRating'] ?? 0,
                    Icons.star_outline_rounded),
                _Metric('Total Reviews', data['totalReviews'] ?? 0,
                    Icons.reviews_outlined),
              ]),
              const SizedBox(height: 18),
              if (total == 0 &&
                  ((data['totalReviews'] as num?)?.toInt() ?? 0) == 0)
                const _AnalyticsEmpty()
              else
                LayoutBuilder(builder: (context, constraints) {
                  final cards = [
                    _Breakdown(title: 'Reservation Status', values: statuses),
                    _Breakdown(
                        title: 'Rating Distribution',
                        values: ratings,
                        suffix: ' star'),
                  ];
                  return constraints.maxWidth >= 820
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                              Expanded(child: cards[0]),
                              const SizedBox(width: 14),
                              Expanded(child: cards[1])
                            ])
                      : Column(children: [
                          cards[0],
                          const SizedBox(height: 14),
                          cards[1]
                        ]);
                }),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: PartnerTheme.cardDecoration(),
                child: Text(
                  data['comparisonPercent'] == null
                      ? 'No previous-period baseline is available yet.'
                      : '${data['comparisonPercent']}% reservation change versus the previous equivalent period.',
                  style: PartnerTheme.label(),
                ),
              ),
            ]);
          },
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.icon);
  final String label;
  final Object value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
        width: 210,
        padding: const EdgeInsets.all(18),
        decoration: PartnerTheme.cardDecoration(),
        child: Row(children: [
          Icon(icon, color: PartnerTheme.primaryOrange),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('$value', style: PartnerTheme.headingSmall()),
                Text(label, style: PartnerTheme.label()),
              ])),
        ]),
      );
}

class _Breakdown extends StatelessWidget {
  const _Breakdown(
      {required this.title, required this.values, this.suffix = ''});
  final String title;
  final Map<String, dynamic> values;
  final String suffix;
  @override
  Widget build(BuildContext context) {
    final max = values.values
        .whereType<num>()
        .fold<num>(0, (current, value) => value > current ? value : current);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: PartnerTheme.cardDecoration(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: PartnerTheme.headingSmall()),
        const SizedBox(height: 14),
        for (final entry in values.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              SizedBox(
                  width: 100,
                  child:
                      Text('${entry.key}$suffix', style: PartnerTheme.label())),
              Expanded(
                  child: LinearProgressIndicator(
                      value: max == 0 ? 0 : ((entry.value as num?) ?? 0) / max,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(8))),
              const SizedBox(width: 10),
              SizedBox(width: 30, child: Text('${entry.value}')),
            ]),
          ),
      ]),
    );
  }
}

class _AnalyticsEmpty extends StatelessWidget {
  const _AnalyticsEmpty();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(40),
        decoration: PartnerTheme.cardDecoration(),
        child: Column(children: [
          const Icon(Icons.query_stats_rounded,
              size: 50, color: PartnerTheme.textMuted),
          const SizedBox(height: 12),
          Text('Not enough activity yet', style: PartnerTheme.headingSmall()),
          Text(
              'Reservation and review analytics will appear as visitors interact with your destination.',
              textAlign: TextAlign.center,
              style: PartnerTheme.label()),
        ]),
      );
}
