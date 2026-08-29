import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/msme_portal_providers.dart';
import '../msme_theme.dart';

class MsmePortalReviewsPage extends ConsumerWidget {
  const MsmePortalReviewsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviews = ref.watch(msmePortalReviewsProvider);
    final stats = ref.watch(msmePortalReviewStatsProvider);
    return Scaffold(
      backgroundColor: MsmeTheme.bgDark,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Customer Reviews', style: MsmeTheme.headingLarge()),
          const Text('Tourist ratings and review text are read-only.',
              style: TextStyle(color: MsmeTheme.textMuted)),
          const SizedBox(height: 10),
          stats.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const SizedBox.shrink(),
            data: (data) => Wrap(spacing: 10, children: [
              Chip(label: Text('Average: ${data['averageRating'] ?? 0}')),
              Chip(label: Text('Reviews: ${data['totalReviews'] ?? 0}')),
            ]),
          ),
          const SizedBox(height: 10),
          Expanded(
              child: reviews.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
                child: OutlinedButton(
                    onPressed: () => ref.invalidate(msmePortalReviewsProvider),
                    child: Text('Retry: $error'))),
            data: (items) => items.isEmpty
                ? const Center(
                    child: Text('No reviews yet.',
                        style: TextStyle(color: MsmeTheme.textMuted)))
                : ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final rating = (item['rating'] as num?)?.toInt() ?? 0;
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: MsmeTheme.cardDecoration(),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item['reviewer']?.toString() ?? 'Tourist',
                                  style: MsmeTheme.headingSmall()),
                              Row(
                                  children: List.generate(
                                      5,
                                      (star) => Icon(
                                          star < rating
                                              ? Icons.star
                                              : Icons.star_border,
                                          color: MsmeTheme.amber,
                                          size: 18))),
                              const SizedBox(height: 8),
                              Text(item['comment']?.toString() ?? '',
                                  style: const TextStyle(color: Colors.white)),
                              Text(item['date']?.toString() ?? '',
                                  style: const TextStyle(
                                      color: MsmeTheme.textMuted)),
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
