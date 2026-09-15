import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../providers/msme_portal_providers.dart';
import '../msme_theme.dart';
import '../widgets/msme_portal_states.dart';

class MsmePortalReviewsPage extends ConsumerStatefulWidget {
  const MsmePortalReviewsPage({super.key});

  @override
  ConsumerState<MsmePortalReviewsPage> createState() => _ReviewsState();
}

class _ReviewsState extends ConsumerState<MsmePortalReviewsPage> {
  String _filter = 'all';
  bool _oldestFirst = false;

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(currentMsmeProvider);
    final reviews = ref.watch(msmePortalReviewsProvider);
    final stats = ref.watch(msmePortalReviewStatsProvider);
    if (current.isLoading) {
      return Scaffold(
          backgroundColor: MsmeTheme.bgDark,
          body: const Center(child: CircularProgressIndicator()));
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
      return Scaffold(
        backgroundColor: MsmeTheme.bgDark,
        body: const MsmeSetupRequired(
          title: 'Create your business profile first',
          message:
              'Customer reviews will appear here after your business is published and receives feedback.',
        ),
      );
    }

    return Scaffold(
      backgroundColor: MsmeTheme.bgDark,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 10,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Customer Reviews', style: MsmeTheme.headingLarge()),
                Text(
                    'Tourist feedback is read-only; owners cannot alter customer reviews.',
                    style: TextStyle(color: MsmeTheme.textMuted)),
              ]),
              IconButton.filledTonal(
                tooltip: 'Refresh reviews',
                onPressed: () => ref.invalidate(msmePortalReviewDataProvider),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 14),
          stats.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const SizedBox.shrink(),
            data: _summary,
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final entry in const {
                'all': 'All',
                '5': '5 Star',
                '4': '4 Star',
                '3': '3 Star',
                'low': 'Low Ratings',
              }.entries)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(entry.value),
                    selected: _filter == entry.key,
                    onSelected: (_) => setState(() => _filter = entry.key),
                  ),
                ),
              ActionChip(
                avatar: Icon(_oldestFirst
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded),
                label: Text(_oldestFirst ? 'Oldest' : 'Recent'),
                onPressed: () => setState(() => _oldestFirst = !_oldestFirst),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: reviews.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => MsmePortalErrorState(
                message: friendlyMsmeError(
                    error, 'We couldn’t load your customer reviews.'),
                onRetry: () => ref.invalidate(msmePortalReviewDataProvider),
              ),
              data: (items) {
                final filtered = items.where((item) {
                  final rating = (item['rating'] as num?)?.toInt() ?? 0;
                  if (_filter == 'low') return rating <= 2;
                  if (_filter == 'all') return true;
                  return rating == int.tryParse(_filter);
                }).toList()
                  ..sort((a, b) {
                    final left =
                        DateTime.tryParse(a['created_at']?.toString() ?? '');
                    final right =
                        DateTime.tryParse(b['created_at']?.toString() ?? '');
                    final result = (left ?? DateTime(1970))
                        .compareTo(right ?? DateTime(1970));
                    return _oldestFirst ? result : -result;
                  });
                if (filtered.isEmpty) {
                  return Center(
                      child: Text('No reviews match this filter.',
                          style: TextStyle(color: MsmeTheme.textMuted)));
                }
                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) => _ReviewCard(filtered[index]),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  Widget _summary(Map<String, dynamic> data) {
    final distribution = data['ratingDistribution'] is Map
        ? Map<String, dynamic>.from(data['ratingDistribution'] as Map)
        : const <String, dynamic>{};
    final total = (data['totalReviews'] as num?)?.toInt() ?? 0;
    final five = (distribution['5'] as num?)?.toInt() ?? 0;
    final fivePercent = total == 0 ? 0 : ((five / total) * 100).round();
    return Wrap(spacing: 10, runSpacing: 10, children: [
      _SummaryCard(
          'Average Rating', data['averageRating'] ?? 0, Icons.star_rounded),
      _SummaryCard('Total Reviews', total, Icons.reviews_rounded),
      _SummaryCard('5-star Reviews', '$fivePercent%', Icons.thumb_up_rounded),
    ]);
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard(this.label, this.value, this.icon);
  final String label;
  final Object value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
        width: 210,
        padding: const EdgeInsets.all(14),
        decoration: MsmeTheme.cardDecoration(),
        child: Row(children: [
          Icon(icon, color: MsmeTheme.primaryOrange),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$value',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            Text(label,
                style:
                    TextStyle(color: MsmeTheme.textMuted, fontSize: 12)),
          ]),
        ]),
      );
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard(this.item);
  final Map<String, dynamic> item;
  @override
  Widget build(BuildContext context) {
    final rating = (item['rating'] as num?)?.toInt() ?? 0;
    final date = DateTime.tryParse(item['date']?.toString() ?? '');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: MsmeTheme.cardDecoration(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
              backgroundColor: MsmeTheme.surfaceDark,
              child: Icon(Icons.person_rounded, color: MsmeTheme.textMuted)),
          const SizedBox(width: 10),
          Expanded(
              child: Text(item['reviewer']?.toString() ?? 'Tourist',
                  style: MsmeTheme.headingSmall())),
          if (date != null)
            Text(DateFormat.yMMMd().format(date.toLocal()),
                style: TextStyle(color: MsmeTheme.textMuted)),
        ]),
        const SizedBox(height: 8),
        Semantics(
          label: '$rating out of 5 stars',
          child: Row(
              children: List.generate(
                  5,
                  (star) => Icon(star < rating ? Icons.star : Icons.star_border,
                      color: MsmeTheme.amber, size: 18))),
        ),
        const SizedBox(height: 8),
        Text(item['comment']?.toString() ?? '',
            style: const TextStyle(color: Colors.white, height: 1.45)),
      ]),
    );
  }
}
