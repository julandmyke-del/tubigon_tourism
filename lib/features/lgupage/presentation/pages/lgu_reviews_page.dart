import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../providers/lgu_providers.dart';
import '../../repositories/lgu_repository.dart';


class LguReviewsPage extends ConsumerStatefulWidget {
  const LguReviewsPage({super.key});

  @override
  ConsumerState<LguReviewsPage> createState() => _LguReviewsPageState();
}

class _LguReviewsPageState extends ConsumerState<LguReviewsPage> {
  static const _navyDark = Color(0xFF0B132B);
  static const _cardBg = Color(0xFF1C2541);

  final List<Map<String, dynamic>> _reviews = [
    {'id': '1', 'tourist': 'Anna L.', 'spot': 'Canigao Island', 'rating': 5, 'comment': 'Absolutely breathtaking! Crystal clear water and pristine white sand.', 'date': 'Aug 2, 2026', 'status': 'Published'},
    {'id': '2', 'tourist': 'Marco R.', 'spot': 'Mangrove Eco Park', 'rating': 4, 'comment': 'Great eco-tourism experience. Passionate guides.', 'date': 'Aug 1, 2026', 'status': 'Published'},
    {'id': '3', 'tourist': 'Sofia P.', 'spot': 'Tubigon Public Market', 'rating': 3, 'comment': 'Needs better organization and cleanliness management.', 'date': 'Jul 31, 2026', 'status': 'Flagged'},
    {'id': '4', 'tourist': 'David K.', 'spot': 'Sipatan Falls', 'rating': 5, 'comment': 'Hidden gem! The hike is worth it.', 'date': 'Jul 30, 2026', 'status': 'Published'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _navyDark,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Community Review Moderation',
              style: AppTypography.headlineSmall.copyWith(
                color: AppColors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text(
              'Monitor tourist feedback, moderate community ratings, and inspect flagged comments',
              style: TextStyle(color: AppColors.grey400, fontSize: 13),
            ),
            const SizedBox(height: AppSpacing.lg),

            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _reviews.length,
              itemBuilder: (context, index) {
                final item = _reviews[index];
                final isFlagged = item['status'] == 'Flagged';

                return Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: _cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isFlagged ? AppColors.error.withValues(alpha: 0.4) : AppColors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(item['tourist'], style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(width: 8),
                              Text('on ${item['spot']}', style: const TextStyle(color: AppColors.grey400, fontSize: 12)),
                            ],
                          ),
                          Row(
                            children: List.generate(5, (starIndex) {
                              return Icon(
                                starIndex < item['rating'] ? Icons.star_rounded : Icons.star_border_rounded,
                                color: Colors.amber,
                                size: 16,
                              );
                            }),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('"${item['comment']}"', style: const TextStyle(color: AppColors.grey200, fontSize: 13, fontStyle: FontStyle.italic)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(item['date'], style: const TextStyle(color: AppColors.grey500, fontSize: 11)),
                          Row(
                            children: [
                              if (isFlagged)
                                TextButton(
                                  onPressed: () {
                                    setState(() => item['status'] = 'Published');
                                    ref.read(lguRepositoryProvider).moderateReview(item['id'], 'Published');
                                  },
                                  child: const Text('Approve Review', style: TextStyle(color: AppColors.success)),
                                )
                              else
                                TextButton(
                                  onPressed: () {
                                    setState(() => item['status'] = 'Flagged');
                                    ref.read(lguRepositoryProvider).moderateReview(item['id'], 'Flagged');
                                  },
                                  child: const Text('Flag Review', style: TextStyle(color: AppColors.error)),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
