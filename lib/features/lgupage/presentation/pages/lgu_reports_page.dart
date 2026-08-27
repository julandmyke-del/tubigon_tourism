import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../providers/lgu_providers.dart';

class LguReportsPage extends ConsumerWidget {
  const LguReportsPage({super.key});

  static const _navyDark = Color(0xFF0B132B);
  static const _cardBg = Color(0xFF1C2541);
  static const _accentOrange = Color(0xFFF97316);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(lguReportPeriodProvider);
    final reportsAsync = ref.watch(lguReportsProvider);

    return Scaffold(
      backgroundColor: _navyDark,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reports & Statistics Generator',
              style: AppTypography.headlineSmall.copyWith(color: AppColors.white, fontWeight: FontWeight.bold),
            ),
            const Text(
              'Generate, review, and export comprehensive municipal tourism and operational reports',
              style: TextStyle(color: AppColors.grey400, fontSize: 13),
            ),
            const SizedBox(height: AppSpacing.md),

            // Period Selector
            Row(
              children: ['daily', 'weekly', 'monthly', 'yearly'].map((p) {
                final isSelected = period == p;
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(p[0].toUpperCase() + p.substring(1)),
                    selected: isSelected,
                    selectedColor: _accentOrange,
                    backgroundColor: _cardBg,
                    labelStyle: TextStyle(
                      color: isSelected ? AppColors.white : AppColors.grey300,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (_) => ref.read(lguReportPeriodProvider.notifier).state = p,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.lg),

            reportsAsync.when(
              data: (data) {
                return Column(
                  children: [
                    // Report Summary Cards
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth > 800;
                        return GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: isWide ? 3 : 1,
                          crossAxisSpacing: AppSpacing.md,
                          mainAxisSpacing: AppSpacing.md,
                          childAspectRatio: isWide ? 2.0 : 3.0,
                          children: [
                            _buildReportCard('Tourism Report', 'Visitor trends, spot performance, and revenue projections', Icons.trending_up_rounded, _accentOrange),
                            _buildReportCard('Environmental Report', 'Waste incidents, cleanups completed, and sustainability KPIs', Icons.eco_rounded, const Color(0xFF22C55E)),
                            _buildReportCard('MSME Compliance Report', 'Business verification status, compliance rates, and trade analytics', Icons.storefront_rounded, const Color(0xFF6366F1)),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Export Action
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: _cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.white.withValues(alpha: 0.08)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Export Municipal Report', style: AppTypography.titleMedium.copyWith(color: AppColors.white, fontWeight: FontWeight.bold)),
                              Text('Generate PDF / Excel for ${period[0].toUpperCase()}${period.substring(1)} period', style: const TextStyle(color: AppColors.grey400, fontSize: 12)),
                            ],
                          ),
                          Row(
                            children: [
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.white,
                                  side: BorderSide(color: AppColors.white.withValues(alpha: 0.2)),
                                ),
                                icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                                label: const Text('PDF'),
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Generating PDF report...')));
                                },
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(backgroundColor: _accentOrange),
                                icon: const Icon(Icons.table_chart_rounded, size: 18, color: AppColors.white),
                                label: const Text('Excel', style: TextStyle(color: AppColors.white)),
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Generating Excel report...')));
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: _accentOrange)),
              error: (_, __) => _buildReportFallback(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportFallback() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 800;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: isWide ? 3 : 1,
          crossAxisSpacing: AppSpacing.md,
          mainAxisSpacing: AppSpacing.md,
          childAspectRatio: isWide ? 2.0 : 3.0,
          children: [
            _buildReportCard('Tourism Report', 'Visitor analytics and revenue projections', Icons.trending_up_rounded, _accentOrange),
            _buildReportCard('Environmental Report', 'Waste management KPIs', Icons.eco_rounded, const Color(0xFF22C55E)),
            _buildReportCard('MSME Compliance', 'Business verification and compliance', Icons.storefront_rounded, const Color(0xFF6366F1)),
          ],
        );
      },
    );
  }

  Widget _buildReportCard(String title, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: AppColors.grey400, fontSize: 12)),
        ],
      ),
    );
  }
}
