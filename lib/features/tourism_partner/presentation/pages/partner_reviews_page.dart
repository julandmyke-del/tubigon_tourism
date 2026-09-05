import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/tourism_partner_providers.dart';
import '../partner_theme.dart';

class PartnerReviewsPage extends ConsumerStatefulWidget {
  const PartnerReviewsPage({super.key});

  @override
  ConsumerState<PartnerReviewsPage> createState() => _PartnerReviewsState();
}

class _PartnerReviewsState extends ConsumerState<PartnerReviewsPage> {
  String _filter = 'all';
  bool _oldest = false;

  @override
  Widget build(BuildContext context) {
    final reviews = ref.watch(partnerReviewsProvider);
    final stats = ref.watch(partnerReviewStatsProvider);
    return Scaffold(
      backgroundColor: PartnerTheme.bgDark,
      body: Padding(
        padding:
            EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 16 : 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Destination Feedback', style: PartnerTheme.headingLarge()),
          Text(
              'Tourist reviews are read-only and scoped to your assigned destination.',
              style: PartnerTheme.label()),
          const SizedBox(height: 14),
          stats.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const SizedBox.shrink(),
            data: (data) => _ReviewSummary(data: data),
          ),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final value in const ['all', '5', '4', '3', 'low'])
              ChoiceChip(
                label: Text(value == 'all'
                    ? 'All'
                    : value == 'low'
                        ? 'Low ratings'
                        : '$value Star'),
                selected: _filter == value,
                onSelected: (_) => setState(() => _filter = value),
              ),
            FilterChip(
              label: Text(_oldest ? 'Oldest first' : 'Newest first'),
              selected: _oldest,
              onSelected: (value) => setState(() => _oldest = value),
            ),
          ]),
          const SizedBox(height: 14),
          Expanded(
            child: reviews.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => Center(
                  child: OutlinedButton(
                onPressed: () => ref.invalidate(partnerReviewsProvider),
                child: const Text("We couldn't load reviews. Retry"),
              )),
              data: (items) {
                final filtered = items.where((item) {
                  final rating = (item['rating'] as num?)?.toInt() ?? 0;
                  return _filter == 'all' ||
                      (_filter == 'low'
                          ? rating <= 2
                          : rating == int.parse(_filter));
                }).toList();
                if (_oldest) {
                  filtered
                      .sort((a, b) => '${a['date']}'.compareTo('${b['date']}'));
                }
                if (filtered.isEmpty) return const _ReviewEmpty();
                return RefreshIndicator(
                  onRefresh: () async {
                    final refreshed =
                        ref.refresh(partnerReviewsProvider.future);
                    await refreshed;
                    if (!context.mounted) return;
                    ref.invalidate(partnerReviewStatsProvider);
                  },
                  child: ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) =>
                        _ReviewCard(item: filtered[index]),
                  ),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

class _ReviewSummary extends StatelessWidget {
  const _ReviewSummary({required this.data});
  final Map<String, dynamic> data;
  @override
  Widget build(BuildContext context) {
    final distribution = data['ratingDistribution'] is Map
        ? data['ratingDistribution'] as Map
        : const {};
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: PartnerTheme.cardDecoration(),
      child: Wrap(
          spacing: 28,
          runSpacing: 14,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${data['averageRating'] ?? 0}',
                  style: PartnerTheme.headingLarge()),
              const Row(children: [
                Icon(Icons.star_rounded, color: PartnerTheme.orange),
                SizedBox(width: 5),
                Text('Average rating')
              ]),
            ]),
            _metric('${data['totalReviews'] ?? 0}', 'Total reviews'),
            _metric('${data['lowRatedReviews'] ?? 0}', 'Needs attention'),
            for (var rating = 5; rating >= 1; rating--)
              Text('$rating star: ${distribution['$rating'] ?? 0}',
                  style: PartnerTheme.label()),
          ]),
    );
  }

  Widget _metric(String value, String label) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: PartnerTheme.headingSmall()),
        Text(label, style: PartnerTheme.label()),
      ]);
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.item});
  final Map<String, dynamic> item;
  @override
  Widget build(BuildContext context) {
    final rating = (item['rating'] as num?)?.toInt() ?? 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: PartnerTheme.cardDecoration(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const CircleAvatar(child: Icon(Icons.person_outline_rounded)),
          const SizedBox(width: 10),
          Expanded(
              child: Text('${item['reviewer'] ?? 'Tourist'}',
                  style: PartnerTheme.headingSmall())),
          if (rating <= 2) const Chip(label: Text('NEEDS ATTENTION')),
        ]),
        const SizedBox(height: 8),
        Row(
            children: List.generate(
                5,
                (star) => Icon(
                    star < rating
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: PartnerTheme.orange,
                    size: 19))),
        const SizedBox(height: 8),
        Text('${item['comment'] ?? ''}',
            style: const TextStyle(color: Colors.white)),
        const SizedBox(height: 6),
        Text('${item['date'] ?? ''}', style: PartnerTheme.label()),
      ]),
    );
  }
}

class _ReviewEmpty extends StatelessWidget {
  const _ReviewEmpty();
  @override
  Widget build(BuildContext context) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.rate_review_outlined,
            size: 48, color: PartnerTheme.textMuted),
        const SizedBox(height: 10),
        Text('No reviews yet', style: PartnerTheme.headingSmall()),
        Text(
            'Tourist feedback will appear after visitors review your destination.',
            textAlign: TextAlign.center,
            style: PartnerTheme.label()),
      ]));
}
