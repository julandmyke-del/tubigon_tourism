import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../providers/tourism_partner_providers.dart';
import '../partner_theme.dart';

class PartnerAnalyticsPage extends ConsumerWidget {
  const PartnerAnalyticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsAsync = ref.watch(partnerAnalyticsProvider);

    return Scaffold(
      backgroundColor: PartnerTheme.bgDark,
      body: analyticsAsync.when(
        data: (data) => _buildAnalyticsContent(context, ref, data),
        loading: () => const Center(child: CircularProgressIndicator(color: PartnerTheme.primaryOrange)),
        error: (_, __) => _buildAnalyticsContent(context, ref, {}),
      ),
    );
  }

  Widget _buildAnalyticsContent(BuildContext context, WidgetRef ref, Map<String, dynamic> data) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text('Business Analytics', style: PartnerTheme.headingLarge()),
          Text('Deep dive into your business growth, revenue trends, and guest demographics.', style: PartnerTheme.label()),
          const SizedBox(height: 24),

          // KPI Cards Grid
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 800;
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: isWide ? 4 : 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.5,
                children: [
                  _kpiCard('Weekly Revenue', '₱16,400', '↑ +28% vs W2', PartnerTheme.primaryOrange, '💰'),
                  _kpiCard('Total Bookings', '139', '7 weekly avg', PartnerTheme.blue, '📅'),
                  _kpiCard('Avg Guest Rating', '4.8 ⭐', 'Top 5% in Bohol', PartnerTheme.green, '⭐'),
                  _kpiCard('Conversion Rate', '15.8%', 'Inquiry to Booking', PartnerTheme.purple, '📈'),
                ],
              );
            },
          ),
          const SizedBox(height: 28),

          // Weekly Revenue Chart + Guest Demographics
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 900;
              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 7, child: _buildWeeklyRevenueChart()),
                    const SizedBox(width: 20),
                    Expanded(flex: 5, child: _buildGuestOriginsChart()),
                  ],
                );
              }
              return Column(
                children: [
                  _buildWeeklyRevenueChart(),
                  const SizedBox(height: 20),
                  _buildGuestOriginsChart(),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Conversion Funnel & Rating Trend
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 900;
              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 6, child: _buildConversionFunnel()),
                    const SizedBox(width: 20),
                    Expanded(flex: 6, child: _buildRatingTrendChart()),
                  ],
                );
              }
              return Column(
                children: [
                  _buildConversionFunnel(),
                  const SizedBox(height: 20),
                  _buildRatingTrendChart(),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _kpiCard(String label, String value, String sub, Color color, String icon) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: PartnerTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(icon, style: const TextStyle(fontSize: 20)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(sub, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w800, color: PartnerTheme.textWhite)),
              Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: PartnerTheme.textMuted)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyRevenueChart() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: PartnerTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Weekly Revenue Trend (PHP)', style: PartnerTheme.headingSmall()),
          Text('Recent 7 weeks breakdown', style: PartnerTheme.label()),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (val, meta) => Text('₱${(val / 1000).toInt()}k', style: GoogleFonts.inter(fontSize: 9, color: PartnerTheme.textDisabled)),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, meta) {
                        const weeks = ['W1 Jul', 'W2 Jul', 'W3 Jul', 'W4 Jul', 'W1 Aug', 'W2 Aug', 'W3 Aug'];
                        if (val.toInt() >= 0 && val.toInt() < weeks.length) {
                          return Text(weeks[val.toInt()], style: GoogleFonts.inter(fontSize: 10, color: PartnerTheme.textDisabled));
                        }
                        return const Text('');
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 8.2), FlSpot(1, 11.4), FlSpot(2, 9.8), FlSpot(3, 13.6), FlSpot(4, 15.2), FlSpot(5, 12.8), FlSpot(6, 16.4),
                    ],
                    isCurved: true,
                    color: PartnerTheme.primaryOrange,
                    barWidth: 3,
                    belowBarData: BarAreaData(show: true, color: PartnerTheme.primaryOrange.withValues(alpha: 0.15)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuestOriginsChart() {
    final origins = [
      _OriginItem('Local (Bohol)', 420, PartnerTheme.primaryOrange),
      _OriginItem('Cebu City', 312, PartnerTheme.blue),
      _OriginItem('Manila', 246, PartnerTheme.green),
      _OriginItem('Davao', 128, PartnerTheme.purple),
      _OriginItem('International', 98, PartnerTheme.cyan),
    ];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: PartnerTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Guest Origins & Demographics', style: PartnerTheme.headingSmall()),
          Text('Top visitor locations this month', style: PartnerTheme.label()),
          const SizedBox(height: 20),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: origins.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, idx) {
              final item = origins[idx];
              final pct = item.count / 1204;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(item.name, style: GoogleFonts.inter(fontSize: 13, color: PartnerTheme.textWhite, fontWeight: FontWeight.w600)),
                      Text('${item.count} guests (${(pct * 100).toStringAsFixed(0)}%)', style: GoogleFonts.inter(fontSize: 12, color: PartnerTheme.textMuted)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 6,
                      backgroundColor: Colors.white.withValues(alpha: 0.06),
                      color: item.color,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildConversionFunnel() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: PartnerTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Conversion Funnel', style: PartnerTheme.headingSmall()),
          Text('Views → Inquiries → Confirmed Bookings', style: PartnerTheme.label()),
          const SizedBox(height: 20),
          _funnelStep('Page Views', '1,920 views', 1.0, PartnerTheme.blue),
          const SizedBox(height: 12),
          _funnelStep('Inquiries Sent', '356 inquiries (18.5%)', 0.4, PartnerTheme.purple),
          const SizedBox(height: 12),
          _funnelStep('Confirmed Bookings', '61 bookings (17.1%)', 0.18, PartnerTheme.primaryOrange),
        ],
      ),
    );
  }

  Widget _funnelStep(String label, String detail, double factor, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: PartnerTheme.textWhite)),
            Text(detail, style: GoogleFonts.inter(fontSize: 12, color: PartnerTheme.textMuted)),
          ],
        ),
        const SizedBox(height: 6),
        FractionallySizedBox(
          widthFactor: factor,
          child: Container(
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRatingTrendChart() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: PartnerTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Customer Satisfaction Rating', style: PartnerTheme.headingSmall()),
          Text('Average monthly rating out of 5.0', style: PartnerTheme.label()),
          const SizedBox(height: 24),
          SizedBox(
            height: 140,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (val, meta) => Text(val.toStringAsFixed(1), style: GoogleFonts.inter(fontSize: 9, color: PartnerTheme.textDisabled)),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, meta) {
                        const months = ['Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug'];
                        if (val.toInt() >= 0 && val.toInt() < months.length) {
                          return Text(months[val.toInt()], style: GoogleFonts.inter(fontSize: 10, color: PartnerTheme.textDisabled));
                        }
                        return const Text('');
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 4.5), FlSpot(1, 4.6), FlSpot(2, 4.7), FlSpot(3, 4.7), FlSpot(4, 4.8), FlSpot(5, 4.9), FlSpot(6, 4.8),
                    ],
                    isCurved: true,
                    color: PartnerTheme.green,
                    barWidth: 3,
                    belowBarData: BarAreaData(show: true, color: PartnerTheme.green.withValues(alpha: 0.15)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OriginItem {
  final String name;
  final int count;
  final Color color;

  _OriginItem(this.name, this.count, this.color);
}
