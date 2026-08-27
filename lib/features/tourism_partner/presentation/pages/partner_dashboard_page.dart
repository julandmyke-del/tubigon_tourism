import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../authentication/auth_provider.dart';
import '../../providers/tourism_partner_providers.dart';
import '../partner_theme.dart';

class PartnerDashboardPage extends ConsumerWidget {
  const PartnerDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(partnerDashboardStatsProvider);
    final auth = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: PartnerTheme.bgDark,
      body: statsAsync.when(
        data: (stats) => _buildDashboardContent(context, ref, stats, auth),
        loading: () => const Center(
          child: CircularProgressIndicator(color: PartnerTheme.primaryOrange),
        ),
        error: (err, stack) => _buildDashboardContent(context, ref, {}, auth), // fallback to dashboard UI with mock fallback
      ),
    );
  }

  Widget _buildDashboardContent(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> stats,
    AuthState auth,
  ) {
    final totalListings = stats['totalListings'] ?? 12;
    final activeListings = stats['activeListings'] ?? 8;
    final pendingReservations = stats['pendingReservations'] ?? 18;
    final confirmedReservations = stats['confirmedReservations'] ?? 61;
    final completedReservations = stats['completedReservations'] ?? 248;
    final totalCustomers = stats['totalCustomers'] ?? 1204;
    final avgRating = stats['avgRating'] ?? 4.8;
    final totalReviews = stats['totalReviews'] ?? 389;

    final statCardsData = [
      _StatCardItem('Total Listings', '$totalListings', '8 active', '📋', PartnerTheme.blue, '+2 this month'),
      _StatCardItem('Active Listings', '$activeListings', '67% of total', '✅', PartnerTheme.green, 'All verified'),
      _StatCardItem('Pending Reservations', '$pendingReservations', 'Needs action', '⏳', PartnerTheme.orange, '5 expiring soon'),
      _StatCardItem('Confirmed', '$confirmedReservations', 'This month', '🎯', PartnerTheme.primaryOrange, '+12% vs last mo.'),
      _StatCardItem('Completed', '$completedReservations', 'All-time', '🏆', PartnerTheme.purple, 'Top performer'),
      _StatCardItem('Total Customers', '$totalCustomers', 'Unique guests', '👥', PartnerTheme.cyan, '+34 this week'),
      _StatCardItem('Average Rating', '$avgRating', 'Out of 5.0', '⭐', PartnerTheme.primaryOrange, '+0.1 this month'),
      _StatCardItem('Total Reviews', '$totalReviews', '98% positive', '💬', PartnerTheme.green, '+28 this week'),
    ];

    return RefreshIndicator(
      onRefresh: () => ref.refresh(partnerDashboardStatsProvider.future),
      color: PartnerTheme.primaryOrange,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Banner
            _buildHeroBanner(context, auth),
            const SizedBox(height: 28),

            // Stat Cards Grid
            LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                int count = 4;
                if (w < 600) {
                  count = 1;
                } else if (w < 1100) {
                  count = 2;
                }
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: count,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.5,
                  ),
                  itemCount: statCardsData.length,
                  itemBuilder: (context, index) {
                    final item = statCardsData[index];
                    return _buildStatCard(item);
                  },
                );
              },
            ),
            const SizedBox(height: 28),

            // Charts Row (Reservation Trend + Category Pie)
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 900;
                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: _buildReservationTrendChart()),
                      const SizedBox(width: 20),
                      Expanded(flex: 1, child: _buildCategoryPieChart()),
                    ],
                  );
                }
                return Column(
                  children: [
                    _buildReservationTrendChart(),
                    const SizedBox(height: 20),
                    _buildCategoryPieChart(),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // Monthly Revenue Bar Chart
            _buildRevenueBarChart(),
            const SizedBox(height: 24),

            // Popular Listings + Recent Activity Row
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 900;
                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 7, child: _buildPopularListings(context)),
                      const SizedBox(width: 20),
                      Expanded(flex: 5, child: _buildRecentActivity()),
                    ],
                  );
                }
                return Column(
                  children: [
                    _buildPopularListings(context),
                    const SizedBox(height: 20),
                    _buildRecentActivity(),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroBanner(BuildContext context, AuthState auth) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: PartnerTheme.heroBannerGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: PartnerTheme.primaryOrange.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'WELCOME BACK, ${(auth.name ?? 'EXPLORER').toUpperCase()}',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: PartnerTheme.primaryOrange,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Your Business Dashboard',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: PartnerTheme.textWhite,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Here's a snapshot of your tourism business performance for August 2026.",
            style: GoogleFonts.inter(fontSize: 14, color: PartnerTheme.textSubtle),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ElevatedButton.icon(
                onPressed: () => context.go('/tourism-partner/listings/create'),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add New Listing'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: PartnerTheme.primaryOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => context.go('/tourism-partner/reservations'),
                icon: const Icon(Icons.calendar_today_rounded, size: 16),
                label: const Text('View Reservations'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: PartnerTheme.textWhite,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => context.go('/tourism-partner/analytics'),
                icon: const Icon(Icons.analytics_rounded, size: 16),
                label: const Text('Analytics'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: PartnerTheme.textWhite,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(_StatCardItem item) {
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
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: item.color.withValues(alpha: 0.25)),
                ),
                child: Center(
                  child: Text(item.icon, style: const TextStyle(fontSize: 18)),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: PartnerTheme.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  item.trend,
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: PartnerTheme.greenLight),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.value,
                style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w800, color: PartnerTheme.textWhite),
              ),
              Text(
                item.label,
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: PartnerTheme.textMuted),
              ),
              Text(
                item.sub,
                style: GoogleFonts.inter(fontSize: 10, color: PartnerTheme.textDisabled),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReservationTrendChart() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: PartnerTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Reservation Trends', style: PartnerTheme.headingSmall()),
                  Text('Last 7 months overview', style: PartnerTheme.label(size: 11)),
                ],
              ),
              Row(
                children: [
                  _chartLegendDot('Confirmed', PartnerTheme.primaryOrange),
                  const SizedBox(width: 12),
                  _chartLegendDot('Pending', PartnerTheme.blue),
                  const SizedBox(width: 12),
                  _chartLegendDot('Cancelled', PartnerTheme.red),
                ],
              ),
            ],
          ),
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
                      reservedSize: 28,
                      getTitlesWidget: (val, meta) => Text(
                        val.toInt().toString(),
                        style: GoogleFonts.inter(fontSize: 10, color: PartnerTheme.textDisabled),
                      ),
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
                      FlSpot(0, 28), FlSpot(1, 35), FlSpot(2, 42), FlSpot(3, 38), FlSpot(4, 55), FlSpot(5, 61), FlSpot(6, 48),
                    ],
                    isCurved: true,
                    color: PartnerTheme.primaryOrange,
                    barWidth: 3,
                    belowBarData: BarAreaData(show: true, color: PartnerTheme.primaryOrange.withValues(alpha: 0.15)),
                  ),
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 8), FlSpot(1, 12), FlSpot(2, 9), FlSpot(3, 14), FlSpot(4, 11), FlSpot(5, 15), FlSpot(6, 18),
                    ],
                    isCurved: true,
                    color: PartnerTheme.blue,
                    barWidth: 2,
                    belowBarData: BarAreaData(show: true, color: PartnerTheme.blue.withValues(alpha: 0.1)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryPieChart() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: PartnerTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bookings by Category', style: PartnerTheme.headingSmall()),
          Text("This month's distribution", style: PartnerTheme.label(size: 11)),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: PieChart(
              PieChartData(
                sectionsSpace: 4,
                centerSpaceRadius: 35,
                sections: [
                  PieChartSectionData(value: 35, color: PartnerTheme.primaryOrange, title: '35%', radius: 30, titleStyle: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                  PieChartSectionData(value: 28, color: PartnerTheme.blue, title: '28%', radius: 28, titleStyle: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                  PieChartSectionData(value: 20, color: PartnerTheme.green, title: '20%', radius: 25, titleStyle: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                  PieChartSectionData(value: 17, color: PartnerTheme.purple, title: '17%', radius: 22, titleStyle: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Column(
            children: [
              _pieLegendItem('Beach', '35%', PartnerTheme.primaryOrange),
              _pieLegendItem('Diving', '28%', PartnerTheme.blue),
              _pieLegendItem('Island Tour', '20%', PartnerTheme.green),
              _pieLegendItem('Snorkeling', '17%', PartnerTheme.purple),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueBarChart() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: PartnerTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Monthly Revenue Performance', style: PartnerTheme.headingSmall()),
                  Text('Total revenue in PHP', style: PartnerTheme.label(size: 11)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('₱169,600', style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w800, color: PartnerTheme.primaryOrange)),
                  Text('↑ +18.4% vs last period', style: GoogleFonts.inter(fontSize: 11, color: PartnerTheme.greenLight)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (val, meta) => Text(
                        '₱${(val / 1000).toInt()}k',
                        style: GoogleFonts.inter(fontSize: 9, color: PartnerTheme.textDisabled),
                      ),
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
                barGroups: [
                  _barGroup(0, 12.4),
                  _barGroup(1, 18.2),
                  _barGroup(2, 22.8),
                  _barGroup(3, 19.6),
                  _barGroup(4, 31.5),
                  _barGroup(5, 36.2, isHighlight: true),
                  _barGroup(6, 28.9),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  BarChartGroupData _barGroup(int x, double y, {bool isHighlight = false}) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: isHighlight ? PartnerTheme.primaryOrange : PartnerTheme.primaryOrange.withValues(alpha: 0.4),
          width: 24,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
        ),
      ],
    );
  }

  Widget _buildPopularListings(BuildContext context) {
    final listings = [
      _PopularListing('Island Hopping Adventure', 48, 4.9, 86400, 12),
      _PopularListing('Scuba Diving Package', 36, 4.8, 72000, 8),
      _PopularListing('Dolphin Watching Trip', 29, 4.7, 52200, 5),
      _PopularListing('Beach BBQ Experience', 22, 4.6, 35200, -2),
      _PopularListing('Snorkeling at Pandanon', 18, 4.8, 27000, 15),
    ];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: PartnerTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Popular Listings', style: PartnerTheme.headingSmall()),
              TextButton(
                onPressed: () => context.go('/tourism-partner/listings'),
                child: Text('View all →', style: GoogleFonts.inter(fontSize: 12, color: PartnerTheme.primaryOrange)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: listings.length,
            separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0x1AFFFFFF)),
            itemBuilder: (context, idx) {
              final item = listings[idx];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        gradient: idx == 0 ? PartnerTheme.orangeGradient : null,
                        color: idx == 0 ? null : Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '#${idx + 1}',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: idx == 0 ? Colors.white : PartnerTheme.textDisabled),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: PartnerTheme.textWhite)),
                          Text('${item.bookings} bookings • ⭐ ${item.rating}', style: GoogleFonts.inter(fontSize: 11, color: PartnerTheme.textDisabled)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('₱${item.revenue}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: PartnerTheme.textWhite)),
                        Text(
                          '${item.trend > 0 ? '↑' : '↓'} ${item.trend.abs()}%',
                          style: GoogleFonts.inter(fontSize: 11, color: item.trend > 0 ? PartnerTheme.greenLight : PartnerTheme.redLight),
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
    );
  }

  Widget _buildRecentActivity() {
    final activities = [
      _Activity('New reservation from Maria Santos for Island Hopping Tour', '5 min ago', PartnerTheme.green),
      _Activity('Juan dela Cruz left a 5-star review on Scuba Diving Package', '22 min ago', PartnerTheme.primaryOrange),
      _Activity('Reservation #R-0045 confirmed for Beach BBQ Experience', '1 hr ago', PartnerTheme.blue),
      _Activity('Payment of ₱3,200 received for Island Hopping Tour', '2 hrs ago', PartnerTheme.purple),
      _Activity('Ana Reyes posted feedback on Dolphin Watching Trip', '3 hrs ago', PartnerTheme.primaryOrange),
    ];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: PartnerTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recent Activity', style: PartnerTheme.headingSmall()),
          const SizedBox(height: 18),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: activities.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, idx) {
              final act = activities[idx];
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: act.color,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: act.color.withValues(alpha: 0.5), blurRadius: 4)],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(act.text, style: GoogleFonts.inter(fontSize: 12, color: PartnerTheme.textMuted, height: 1.4)),
                        const SizedBox(height: 2),
                        Text(act.time, style: GoogleFonts.inter(fontSize: 10, color: PartnerTheme.textDisabled)),
                      ],
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

  Widget _chartLegendDot(String label, Color color) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 4),
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: PartnerTheme.textDisabled)),
      ],
    );
  }

  Widget _pieLegendItem(String name, String pct, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Expanded(child: Text(name, style: GoogleFonts.inter(fontSize: 12, color: PartnerTheme.textMuted))),
          Text(pct, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: PartnerTheme.textWhite)),
        ],
      ),
    );
  }
}

class _StatCardItem {
  final String label;
  final String value;
  final String sub;
  final String icon;
  final Color color;
  final String trend;

  _StatCardItem(this.label, this.value, this.sub, this.icon, this.color, this.trend);
}

class _PopularListing {
  final String name;
  final int bookings;
  final double rating;
  final int revenue;
  final int trend;

  _PopularListing(this.name, this.bookings, this.rating, this.revenue, this.trend);
}

class _Activity {
  final String text;
  final String time;
  final Color color;

  _Activity(this.text, this.time, this.color);
}
