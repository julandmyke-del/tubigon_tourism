import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/admin_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../providers/admin_providers.dart';

class AdminAnalyticsPage extends ConsumerStatefulWidget {
  const AdminAnalyticsPage({super.key});

  @override
  ConsumerState<AdminAnalyticsPage> createState() => _AdminAnalyticsPageState();
}

class _AdminAnalyticsPageState extends ConsumerState<AdminAnalyticsPage> {
  String _selectedYear = '2026';

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(adminDashboardStatsProvider);

    return Scaffold(
      backgroundColor: AdminColors.navy950,
      body: statsAsync.when(
        data: (stats) {
          final totalUsers = stats['totalUsers'] ?? 1247;
          final totalReservations = stats['totalReservations'] ?? 184;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Page Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tourism Analytics & Metrics',
                          style: AppTypography.headlineMedium.copyWith(
                            color: AdminColors.textPrimary,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Data-driven insights, visitor trends, municipal revenue, and spot performance.',
                          style: AppTypography.bodyMedium.copyWith(color: AdminColors.textSecondary),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AdminColors.navy900,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AdminColors.cardBorder),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          dropdownColor: AdminColors.navy900,
                          value: _selectedYear,
                          icon: const Icon(Icons.calendar_today_rounded, color: AdminColors.orange, size: 16),
                          style: const TextStyle(color: AdminColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                          items: ['2026', '2025'].map((y) => DropdownMenuItem(value: y, child: Text('Year $y'))).toList(),
                          onChanged: (val) => setState(() => _selectedYear = val!),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),

                // Top Metrics Grid
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 900;
                    return GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: isWide ? 4 : 2,
                      crossAxisSpacing: AppSpacing.md,
                      mainAxisSpacing: AppSpacing.md,
                      childAspectRatio: isWide ? 1.6 : 2.0,
                      children: [
                        _AnalyticsCard(
                          title: 'Est. Tourism Revenue',
                          value: '₱258,000',
                          sub: '+14.2% vs last month',
                          icon: Icons.payments_rounded,
                          color: AdminColors.success,
                        ),
                        _AnalyticsCard(
                          title: 'Monthly Visitors',
                          value: '17,200',
                          sub: '+8.5% visitor influx',
                          icon: Icons.groups_rounded,
                          color: AdminColors.info,
                        ),
                        _AnalyticsCard(
                          title: 'Reservation Rate',
                          value: '$totalReservations',
                          sub: '92% completion rate',
                          icon: Icons.calendar_month_rounded,
                          color: AdminColors.purple,
                        ),
                        _AnalyticsCard(
                          title: 'Platform Registered Users',
                          value: '$totalUsers',
                          sub: 'Active tourist profiles',
                          icon: Icons.person_outline_rounded,
                          color: AdminColors.orange,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.lg),

                // Visitor Trend Breakdown
                Container(
                  decoration: AdminColors.glassDecoration(),
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Monthly Visitor Influx Trend (2026)',
                            style: AppTypography.titleMedium.copyWith(color: AdminColors.textPrimary, fontWeight: FontWeight.bold),
                          ),
                          const Text('Peak: July (17.2k)', style: TextStyle(color: AdminColors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const _BarChartMock(),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Category Distribution Progress Bars
                Container(
                  decoration: AdminColors.glassDecoration(),
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tourism Category Share Distribution',
                        style: AppTypography.titleMedium.copyWith(color: AdminColors.textPrimary, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const _CategoryShareBar(label: 'Beach & Island Attractions', percentage: 0.38, color: AdminColors.info),
                      const _CategoryShareBar(label: 'Heritage & Cultural Landmarks', percentage: 0.22, color: AdminColors.purple),
                      const _CategoryShareBar(label: 'Eco-Tourism & Nature Reserves', percentage: 0.18, color: AdminColors.success),
                      const _CategoryShareBar(label: 'Port & Public Markets', percentage: 0.12, color: AdminColors.orange),
                      const _CategoryShareBar(label: 'Natural Wonders', percentage: 0.10, color: AdminColors.warning),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AdminColors.orange)),
        error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: AdminColors.danger))),
      ),
    );
  }
}

class _AnalyticsCard extends StatelessWidget {
  final String title;
  final String value;
  final String sub;
  final IconData icon;
  final Color color;

  const _AnalyticsCard({
    required this.title,
    required this.value,
    required this.sub,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AdminColors.glassDecoration(),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color, size: 18),
              ),
              Text(sub, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(color: AdminColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w800)),
              Text(title, style: const TextStyle(color: AdminColors.textSecondary, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryShareBar extends StatelessWidget {
  final String label;
  final double percentage;
  final Color color;

  const _CategoryShareBar({
    required this.label,
    required this.percentage,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: AdminColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
              Text('${(percentage * 100).toInt()}%', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage,
              minHeight: 8,
              backgroundColor: AdminColors.navy900,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}

class _BarChartMock extends StatelessWidget {
  const _BarChartMock();

  @override
  Widget build(BuildContext context) {
    final months = [
      {'m': 'Jan', 'val': 0.45},
      {'m': 'Feb', 'val': 0.55},
      {'m': 'Mar', 'val': 0.65},
      {'m': 'Apr', 'val': 0.60},
      {'m': 'May', 'val': 0.78},
      {'m': 'Jun', 'val': 0.88},
      {'m': 'Jul', 'val': 1.00},
      {'m': 'Aug', 'val': 0.95},
    ];

    return Container(
      height: 180,
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: months.map((item) {
          final val = item['val'] as double;
          final m = item['m'] as String;

          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                width: 28,
                height: 140 * val,
                decoration: BoxDecoration(
                  color: AdminColors.orange.withValues(alpha: val == 1.0 ? 1.0 : 0.6),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: val == 1.0 ? const [BoxShadow(color: AdminColors.orangeGlow, blurRadius: 10)] : null,
                ),
              ),
              const SizedBox(height: 8),
              Text(m, style: const TextStyle(color: AdminColors.textSecondary, fontSize: 11)),
            ],
          );
        }).toList(),
      ),
    );
  }
}
