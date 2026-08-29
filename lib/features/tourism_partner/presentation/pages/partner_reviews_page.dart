import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/tourism_partner_providers.dart';
import '../partner_theme.dart';

class PartnerReviewsPage extends ConsumerWidget {
  const PartnerReviewsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviews = ref.watch(partnerReviewsProvider);
    final stats = ref.watch(partnerReviewStatsProvider);
    return Scaffold(
      backgroundColor: PartnerTheme.bgDark,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Listing Reviews', style: PartnerTheme.headingLarge()),
          Text('Tourist feedback is read-only for partners.',
              style: PartnerTheme.label()),
          const SizedBox(height: 12),
          stats.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const SizedBox.shrink(),
            data: (data) => Wrap(spacing: 16, children: [
              Chip(label: Text('Average: ${data['averageRating'] ?? 0}')),
              Chip(label: Text('Reviews: ${data['totalReviews'] ?? 0}')),
            ]),
          ),
          const SizedBox(height: 12),
          Expanded(
              child: reviews.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
                child: OutlinedButton(
              onPressed: () => ref.invalidate(partnerReviewsProvider),
              child: Text('Retry: $error'),
            )),
            data: (items) => items.isEmpty
                ? const Center(
                    child: Text('No reviews yet.',
                        style: TextStyle(color: PartnerTheme.textMuted)))
                : ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final rating = (item['rating'] as num?)?.toInt() ?? 0;
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: PartnerTheme.cardDecoration(),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item['reviewer']?.toString() ?? 'Tourist',
                                  style: PartnerTheme.headingSmall()),
                              Row(
                                  children: List.generate(
                                      5,
                                      (star) => Icon(
                                            star < rating
                                                ? Icons.star_rounded
                                                : Icons.star_border_rounded,
                                            color: PartnerTheme.orange,
                                            size: 18,
                                          ))),
                              const SizedBox(height: 8),
                              Text(item['comment']?.toString() ?? '',
                                  style: const TextStyle(color: Colors.white)),
                              Text(item['date']?.toString() ?? '',
                                  style: const TextStyle(
                                      color: PartnerTheme.textMuted)),
                            ]),
                      );
                    },
                  ),
          )),
        ]),
      ),
    );
  }
}
