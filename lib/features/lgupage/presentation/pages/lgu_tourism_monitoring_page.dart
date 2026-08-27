import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

class LguTourismMonitoringPage extends ConsumerWidget {
  const LguTourismMonitoringPage({super.key});

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
              'Real-Time Tourism Density & Influx',
              style: AppTypography.headlineSmall.copyWith(
                color: AppColors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text(
              'Spatial distribution, port foot-traffic, and live destination occupancy',
              style: TextStyle(color: AppColors.grey400, fontSize: 13),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Density Cards
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 800;
                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: isWide ? 3 : 1,
                  crossAxisSpacing: AppSpacing.md,
                  mainAxisSpacing: AppSpacing.md,
                  childAspectRatio: isWide ? 1.8 : 2.2,
                  children: [
                    _buildDensityCard('Tubigon Wharf Port', 'Foot Traffic: High', '5,100 visitors/day', Colors.redAccent, Icons.anchor_rounded),
                    _buildDensityCard('Canigao Island Shore', 'Capacity: 82% Occupied', '1,240 active tourists', _accentOrange, Icons.beach_access_rounded),
                    _buildDensityCard('Mangrove Eco Park', 'Capacity: 35% Occupied', '420 active tourists', AppColors.success, Icons.park_rounded),
                  ],
                );
              },
            ),
            const SizedBox(height: AppSpacing.lg),

            // Live Foot Traffic Table
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
                  Text(
                    'Live Spatial Density Monitor',
                    style: AppTypography.titleMedium.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _buildMonitorRow('Canigao Island', 'Island Beach', '1,240', '82% Capacity', Colors.orange),
                  _buildMonitorRow('Tubigon Public Market', 'Town Center', '3,820', '91% Capacity', Colors.redAccent),
                  _buildMonitorRow('Bohol Heritage Shrine', 'Cultural District', '980', '45% Capacity', AppColors.success),
                  _buildMonitorRow('Sipatan Falls', 'Nature Reserve', '680', '60% Capacity', Colors.blue),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDensityCard(String name, String status, String subtitle, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 26),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                child: Text(status, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          Text(name, style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          Text(subtitle, style: const TextStyle(color: AppColors.grey400, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildMonitorRow(String name, String zone, String count, String cap, Color badgeColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              Text('Zone: $zone', style: const TextStyle(color: AppColors.grey400, fontSize: 11)),
            ],
          ),
          Row(
            children: [
              Text(count, style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: badgeColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                child: Text(cap, style: TextStyle(color: badgeColor, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
