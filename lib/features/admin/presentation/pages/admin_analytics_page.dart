import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/admin_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../providers/admin_providers.dart';

class AdminAnalyticsPage extends ConsumerWidget {
  const AdminAnalyticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(adminDashboardStatsProvider);

    return Scaffold(
      backgroundColor: AdminColors.navy950,
      body: statsAsync.when(
        data: (stats) => SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tourism Metrics',
                          style: AppTypography.headlineMedium.copyWith(
                            color: AdminColors.textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Current totals from the operational database.',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AdminColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh metrics',
                    onPressed: () =>
                        ref.invalidate(adminDashboardStatsProvider),
                    icon: const Icon(Icons.refresh_rounded,
                        color: AdminColors.orange),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 1000
                      ? 4
                      : constraints.maxWidth >= 600
                          ? 2
                          : 1;
                  final cards = [
                    (
                      'Registered Users',
                      stats['totalUsers'],
                      Icons.people_rounded,
                      AdminColors.orange
                    ),
                    (
                      'Tourists',
                      stats['totalTourists'],
                      Icons.hiking_rounded,
                      AdminColors.info
                    ),
                    (
                      'MSMEs',
                      stats['totalMsmes'],
                      Icons.store_rounded,
                      AdminColors.purple
                    ),
                    (
                      'Tourist Spots',
                      stats['totalSpots'],
                      Icons.landscape_rounded,
                      AdminColors.success
                    ),
                    (
                      'Reservations',
                      stats['totalReservations'],
                      Icons.calendar_month_rounded,
                      AdminColors.warning
                    ),
                    (
                      'Reviews',
                      stats['totalReviews'],
                      Icons.rate_review_rounded,
                      AdminColors.info
                    ),
                    (
                      'Waste Reports',
                      stats['totalWasteReports'],
                      Icons.delete_outline_rounded,
                      AdminColors.danger
                    ),
                  ];
                  return GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: columns,
                    crossAxisSpacing: AppSpacing.md,
                    mainAxisSpacing: AppSpacing.md,
                    childAspectRatio: columns == 1 ? 3.2 : 1.8,
                    children: cards
                        .map((card) => _MetricCard(
                              title: card.$1,
                              value: (card.$2 as num?)?.toInt() ?? 0,
                              icon: card.$3,
                              color: card.$4,
                            ))
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: AdminColors.glassDecoration(),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Trend analytics',
                        style: TextStyle(
                            color: AdminColors.textPrimary,
                            fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text(
                      'No time-series, visitor, or revenue dataset is available yet. '
                      'No estimates or sample charts are shown.',
                      style: TextStyle(color: AdminColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        loading: () => const Center(
          child: CircularProgressIndicator(color: AdminColors.orange),
        ),
        error: (_, __) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Unable to load metrics.',
                  style: TextStyle(color: AdminColors.danger)),
              TextButton(
                onPressed: () => ref.invalidate(adminDashboardStatsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final int value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: AdminColors.glassDecoration(),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$value',
                    style: const TextStyle(
                        color: AdminColors.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w800)),
                Text(title,
                    style: const TextStyle(
                        color: AdminColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
