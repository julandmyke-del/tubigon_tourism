import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

class LguAnalyticsPage extends ConsumerWidget {
  const LguAnalyticsPage({super.key});

  static const _navyDark = Color(0xFF0B132B);
  static const _cardBg = Color(0xFF1C2541);
  static const _accentOrange = Color(0xFFF97316);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: _navyDark,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tourism Analytics & Performance Metrics',
              style: AppTypography.headlineSmall.copyWith(color: AppColors.white, fontWeight: FontWeight.bold),
            ),
            const Text(
              'Comprehensive data analysis of municipal tourism performance, revenue projections, and operational KPIs',
              style: TextStyle(color: AppColors.grey400, fontSize: 13),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Revenue & Visitor KPI Cards
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 800;
                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: isWide ? 4 : 2,
                  crossAxisSpacing: AppSpacing.md,
                  mainAxisSpacing: AppSpacing.md,
                  childAspectRatio: isWide ? 1.6 : 2.0,
                  children: [
                    _buildKpiCard('Est. Tourism Revenue', '₱512,000', '+18.3% YoY', Icons.payments_rounded, AppColors.success),
                    _buildKpiCard('Monthly Visitors', '12,800', '+14.2% vs prior', Icons.groups_rounded, AppColors.info),
                    _buildKpiCard('Reservation Rate', '92%', 'Completion rate', Icons.calendar_month_rounded, const Color(0xFF6366F1)),
                    _buildKpiCard('Avg. Spot Rating', '4.5★', 'Based on 1,024 reviews', Icons.star_rounded, Colors.amber),
                  ],
                );
              },
            ),
            const SizedBox(height: AppSpacing.lg),

            // Weekly Activity Chart
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.white.withValues(alpha: 0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Weekly Municipal Activity Snapshot', style: AppTypography.titleMedium.copyWith(color: AppColors.white, fontWeight: FontWeight.bold)),
                  const Text('Spot visits, MSME activity, and environmental reports', style: TextStyle(color: AppColors.grey400, fontSize: 12)),
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    height: 220,
                    child: BarChart(
                      BarChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (_) => FlLine(color: AppColors.white.withValues(alpha: 0.05), strokeWidth: 1),
                        ),
                        titlesData: FlTitlesData(
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                                if (value.toInt() >= 0 && value.toInt() < days.length) {
                                  return Text(days[value.toInt()], style: const TextStyle(color: AppColors.grey400, fontSize: 11));
                                }
                                return const SizedBox();
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 32,
                              getTitlesWidget: (value, meta) {
                                return Text('${(value / 1000).toStringAsFixed(1)}k', style: const TextStyle(color: AppColors.grey400, fontSize: 10));
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        barGroups: [
                          _buildBarGroup(0, 820),
                          _buildBarGroup(1, 960),
                          _buildBarGroup(2, 1100),
                          _buildBarGroup(3, 890),
                          _buildBarGroup(4, 1340),
                          _buildBarGroup(5, 1820),
                          _buildBarGroup(6, 2100),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  BarChartGroupData _buildBarGroup(int x, double y) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          width: 18,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          gradient: const LinearGradient(colors: [_accentOrange, Color(0xFFFF8C00)], begin: Alignment.bottomCenter, end: Alignment.topCenter),
        ),
      ],
    );
  }

  Widget _buildKpiCard(String title, String value, String sub, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          Text(value, style: AppTypography.headlineSmall.copyWith(color: AppColors.white, fontWeight: FontWeight.bold)),
          Text(title, style: const TextStyle(color: AppColors.grey400, fontSize: 12)),
          Text(sub, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
