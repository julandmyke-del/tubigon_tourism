import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../providers/lgu_providers.dart';

class LguDashboardPage extends ConsumerWidget {
  const LguDashboardPage({super.key});

  static const _cardBg = Color(0xFF1C2541);
  static const _navyDark = Color(0xFF0B132B);
  static const _accentOrange = Color(0xFFF97316);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(lguDashboardStatsProvider);

    return Scaffold(
      backgroundColor: _navyDark,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Header Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1C2541), Color(0xFF0D1B2A)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.white.withValues(alpha: 0.1)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _accentOrange.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _accentOrange.withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                'OFFICIAL LGU DASHBOARD',
                                style: AppTypography.labelSmall.copyWith(
                                  color: _accentOrange,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              '• Real-Time Municipal Monitor',
                              style: TextStyle(color: AppColors.grey400, fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Executive Municipal Overview',
                          style: AppTypography.headlineSmall.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Monitor tourist spots, business verification, environmental issues, and tourism influx.',
                          style: TextStyle(color: AppColors.grey400, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Top Stat Cards
            statsAsync.when(
              data: (stats) {
                final monthlyVisitors = stats['monthlyVisitors'] ?? '12,800';
                final activeSpots = stats['totalSpots'] ?? '38';
                final verifiedMsme = stats['verifiedMsmes'] ?? '42';
                final wasteResolution = stats['wasteResolutionRate'] ?? '88%';

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 800;
                    return GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: isWide ? 4 : 2,
                      crossAxisSpacing: AppSpacing.md,
                      mainAxisSpacing: AppSpacing.md,
                      childAspectRatio: isWide ? 1.5 : 1.8,
                      children: [
                        _buildStatCard(
                          title: 'Monthly Tourist Influx',
                          value: '$monthlyVisitors',
                          sub: '+14.2% vs last month',
                          icon: Icons.groups_rounded,
                          color: AppColors.info,
                        ),
                        _buildStatCard(
                          title: 'Active Tourist Spots',
                          value: '$activeSpots',
                          sub: '98% operational',
                          icon: Icons.place_rounded,
                          color: _accentOrange,
                        ),
                        _buildStatCard(
                          title: 'Verified MSMEs',
                          value: '$verifiedMsme',
                          sub: 'Licensed local businesses',
                          icon: Icons.storefront_rounded,
                          color: AppColors.success,
                        ),
                        _buildStatCard(
                          title: 'Waste Resolution Rate',
                          value: '$wasteResolution',
                          sub: 'Municipal cleanups resolved',
                          icon: Icons.recycling_rounded,
                          color: Colors.tealAccent,
                        ),
                      ],
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: _accentOrange)),
              error: (_, __) => _buildStatCardFallback(),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Charts Grid Section
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 900;
                return isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: _buildVisitorTrendChart()),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(flex: 2, child: _buildSpotBreakdownChart()),
                        ],
                      )
                    : Column(
                        children: [
                          _buildVisitorTrendChart(),
                          const SizedBox(height: AppSpacing.md),
                          _buildSpotBreakdownChart(),
                        ],
                      );
              },
            ),

            const SizedBox(height: AppSpacing.lg),

            // Recent Activity & Quick Actions
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 900;
                return isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: _buildRecentActivityTable(context)),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(flex: 2, child: _buildQuickActionsCard(context)),
                        ],
                      )
                    : Column(
                        children: [
                          _buildRecentActivityTable(context),
                          const SizedBox(height: AppSpacing.md),
                          _buildQuickActionsCard(context),
                        ],
                      );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCardFallback() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 800;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: isWide ? 4 : 2,
          crossAxisSpacing: AppSpacing.md,
          mainAxisSpacing: AppSpacing.md,
          childAspectRatio: isWide ? 1.5 : 1.8,
          children: [
            _buildStatCard(title: 'Monthly Tourist Influx', value: '12,800', sub: '+14.2%', icon: Icons.groups_rounded, color: AppColors.info),
            _buildStatCard(title: 'Active Tourist Spots', value: '38', sub: '98% active', icon: Icons.place_rounded, color: _accentOrange),
            _buildStatCard(title: 'Verified MSMEs', value: '42', sub: 'Active registry', icon: Icons.storefront_rounded, color: AppColors.success),
            _buildStatCard(title: 'Waste Resolution Rate', value: '88%', sub: 'High response rate', icon: Icons.recycling_rounded, color: Colors.tealAccent),
          ],
        );
      },
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String sub,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
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
              const Icon(Icons.trending_up_rounded, color: AppColors.success, size: 18),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: AppTypography.headlineSmall.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: const TextStyle(color: AppColors.grey400, fontSize: 12),
              ),
            ],
          ),
          Text(
            sub,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildVisitorTrendChart() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tourist Influx Trend (2026)',
                    style: AppTypography.titleMedium.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'Monthly visitor arrivals in Tubigon destinations',
                    style: TextStyle(color: AppColors.grey400, fontSize: 12),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.grey800,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('2026 YTD', style: TextStyle(color: AppColors.white, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
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
                        const months = ['Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug'];
                        if (value.toInt() >= 0 && value.toInt() < months.length) {
                          return Text(months[value.toInt()], style: const TextStyle(color: AppColors.grey400, fontSize: 11));
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
                        return Text('${(value / 1000).toInt()}k', style: const TextStyle(color: AppColors.grey400, fontSize: 10));
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 3200),
                      FlSpot(1, 4100),
                      FlSpot(2, 5800),
                      FlSpot(3, 7200),
                      FlSpot(4, 9400),
                      FlSpot(5, 11200),
                      FlSpot(6, 12800),
                    ],
                    isCurved: true,
                    color: _accentOrange,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          _accentOrange.withValues(alpha: 0.35),
                          _accentOrange.withValues(alpha: 0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpotBreakdownChart() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Spot Category Influx',
            style: AppTypography.titleMedium.copyWith(
              color: AppColors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Text(
            'Distribution across destination types',
            style: TextStyle(color: AppColors.grey400, fontSize: 12),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 180,
            child: PieChart(
              PieChartData(
                sectionsSpace: 4,
                centerSpaceRadius: 40,
                sections: [
                  PieChartSectionData(value: 38, color: _accentOrange, title: '38%', radius: 35, titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                  PieChartSectionData(value: 22, color: const Color(0xFF6366F1), title: '22%', radius: 35, titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                  PieChartSectionData(value: 18, color: const Color(0xFF22C55E), title: '18%', radius: 35, titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                  PieChartSectionData(value: 12, color: const Color(0xFF06B6D4), title: '12%', radius: 35, titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                  PieChartSectionData(value: 10, color: Colors.grey, title: '10%', radius: 35, titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              _buildLegend('Beaches', _accentOrange),
              _buildLegend('Heritage', const Color(0xFF6366F1)),
              _buildLegend('Eco Sites', const Color(0xFF22C55E)),
              _buildLegend('Markets', const Color(0xFF06B6D4)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: AppColors.grey300, fontSize: 11)),
      ],
    );
  }

  Widget _buildRecentActivityTable(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Municipal Submissions',
                style: AppTypography.titleMedium.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () => context.go('/lgu/waste-reports'),
                child: const Text('View All', style: TextStyle(color: _accentOrange)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          _buildActivityItem('Waste Report #104', 'Canigao Beach Shore - High Severity', '5 mins ago', AppColors.warning),
          _buildActivityItem('MSME Application', 'Bohol Crafts & Souvenirs pending verification', '20 mins ago', AppColors.info),
          _buildActivityItem('Ferry Schedule Update', 'Jagna-Tubigon trip added for 3:00 PM', '1 hour ago', AppColors.success),
          _buildActivityItem('Community Review', 'New 5-star rating on Mangrove Eco Park', '2 hours ago', Colors.purpleAccent),
        ],
      ),
    );
  }

  Widget _buildActivityItem(String title, String subtitle, String time, Color tagColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: tagColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: AppColors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                Text(subtitle, style: const TextStyle(color: AppColors.grey400, fontSize: 12)),
              ],
            ),
          ),
          Text(time, style: const TextStyle(color: AppColors.grey500, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildQuickActionsCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Municipal Actions',
            style: AppTypography.titleMedium.copyWith(
              color: AppColors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildActionButton(context, Icons.storefront_rounded, 'Verify Pending MSMEs', '/lgu/msme'),
          _buildActionButton(context, Icons.delete_sweep_rounded, 'Review Waste Reports', '/lgu/waste-reports'),
          _buildActionButton(context, Icons.campaign_rounded, 'Publish Announcement', '/lgu/announcements'),
          _buildActionButton(context, Icons.assessment_rounded, 'Generate Tourism Report', '/lgu/reports'),
        ],
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, IconData icon, String label, String route) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.white,
          side: BorderSide(color: AppColors.white.withValues(alpha: 0.12)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          alignment: Alignment.centerLeft,
        ),
        onPressed: () => context.go(route),
        child: Row(
          children: [
            Icon(icon, color: _accentOrange, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
            const Icon(Icons.chevron_right_rounded, color: AppColors.grey500, size: 18),
          ],
        ),
      ),
    );
  }
}
