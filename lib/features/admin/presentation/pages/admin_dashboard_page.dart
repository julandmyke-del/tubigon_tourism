import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/admin_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../providers/admin_providers.dart';

class AdminDashboardPage extends ConsumerWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(adminDashboardStatsProvider);

    return Scaffold(
      backgroundColor: AdminColors.navy950,
      body: statsAsync.when(
        data: (stats) {
          final totalUsers = stats['totalUsers'] ?? 1247;
          final totalSpots = stats['totalSpots'] ?? 48;
          final totalMsmes = stats['totalMsmes'] ?? 134;
          final totalReservations = stats['totalReservations'] ?? 23;
          final List<dynamic> activities = stats['recentActivities'] ?? [];

          return RefreshIndicator(
            color: AdminColors.orange,
            backgroundColor: AdminColors.navy900,
            onRefresh: () => ref.refresh(adminDashboardStatsProvider.future),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              physics: const AlwaysScrollableScrollPhysics(),
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
                            'Admin Dashboard',
                            style: AppTypography.headlineMedium.copyWith(
                              color: AdminColors.textPrimary,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Welcome back, System Administrator — here\'s what\'s happening in Tubigon today.',
                            style: AppTypography.bodyMedium.copyWith(color: AdminColors.textSecondary),
                          ),
                        ],
                      ),
                      IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: AdminColors.cardBg,
                          side: const BorderSide(color: AdminColors.cardBorder),
                        ),
                        onPressed: () => ref.invalidate(adminDashboardStatsProvider),
                        icon: const Icon(Icons.refresh_rounded, color: AdminColors.orange),
                        tooltip: 'Refresh Stats',
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // 4 Top Stat Cards Grid
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 900;
                      final isMedium = constraints.maxWidth > 600;

                      int crossAxisCount = 1;
                      if (isWide) {
                        crossAxisCount = 4;
                      } else if (isMedium) {
                        crossAxisCount = 2;
                      }

                      return GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: AppSpacing.md,
                        mainAxisSpacing: AppSpacing.md,
                        childAspectRatio: isWide ? 1.5 : (isMedium ? 2.0 : 2.2),
                        children: [
                          _StatCard(
                            label: 'Total Registered Users',
                            value: '$totalUsers',
                            sub: '+12% this month',
                            isUp: true,
                            icon: Icons.people_rounded,
                            color: AdminColors.info,
                            onTap: () => context.go('/admin/users'),
                          ),
                          _StatCard(
                            label: 'Active Tourism Spots',
                            value: '$totalSpots',
                            sub: '+3 this month',
                            isUp: true,
                            icon: Icons.landscape_rounded,
                            color: AdminColors.success,
                            onTap: () => context.go('/admin/tourism'),
                          ),
                          _StatCard(
                            label: 'MSME Registrations',
                            value: '$totalMsmes',
                            sub: '8 pending review',
                            isUp: null,
                            icon: Icons.store_rounded,
                            color: AdminColors.orange,
                            onTap: () => context.go('/admin/msmes'),
                          ),
                          _StatCard(
                            label: 'Reservations Today',
                            value: '$totalReservations',
                            sub: '-4% vs yesterday',
                            isUp: false,
                            icon: Icons.calendar_month_rounded,
                            color: AdminColors.purple,
                            onTap: () => context.go('/admin/reservations'),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Quick Action Shortcuts Grid
                  Text(
                    'Quick Municipal Actions',
                    style: AppTypography.titleMedium.copyWith(color: AdminColors.textPrimary, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.sm,
                    children: [
                      _QuickActionButton(
                        icon: Icons.person_add_rounded,
                        label: 'Manage Users',
                        onTap: () => context.go('/admin/users'),
                      ),
                      _QuickActionButton(
                        icon: Icons.verified_user_rounded,
                        label: 'Verify MSMEs',
                        onTap: () => context.go('/admin/msmes'),
                      ),
                      _QuickActionButton(
                        icon: Icons.add_location_alt_rounded,
                        label: 'Update Spots',
                        onTap: () => context.go('/admin/tourism'),
                      ),
                      _QuickActionButton(
                        icon: Icons.campaign_rounded,
                        label: 'Post Bulletin',
                        onTap: () => context.go('/admin/announcements'),
                      ),
                      _QuickActionButton(
                        icon: Icons.analytics_rounded,
                        label: 'View Analytics',
                        onTap: () => context.go('/admin/analytics'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Recent System Activity Log
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
                              'Recent System Activity Audit',
                              style: AppTypography.titleMedium.copyWith(
                                color: AdminColors.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextButton(
                              onPressed: () => context.go('/admin/logs'),
                              child: const Text('View All Logs →', style: TextStyle(color: AdminColors.orange)),
                            ),
                          ],
                        ),
                        const Divider(color: AdminColors.cardBorder, height: 24),
                        if (activities.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                            child: Center(
                              child: Text(
                                'No recent activity logs available.',
                                style: TextStyle(color: AdminColors.textSecondary),
                              ),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: activities.length > 5 ? 5 : activities.length,
                            separatorBuilder: (_, __) => const Divider(color: AdminColors.cardBorder, height: 16),
                            itemBuilder: (context, idx) {
                              final item = activities[idx] as Map<String, dynamic>;
                              final action = item['action'] ?? item['description'] ?? 'System Event';
                              final time = item['created_at'] ?? item['time'] ?? 'Just now';

                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: AdminColors.orangeDim,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.history_rounded, color: AdminColors.orange, size: 18),
                                ),
                                title: Text(
                                  action,
                                  style: AppTypography.titleSmall.copyWith(color: AdminColors.textPrimary, fontWeight: FontWeight.w600),
                                ),
                                subtitle: Text(
                                  time,
                                  style: AppTypography.labelSmall.copyWith(color: AdminColors.textSecondary),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AdminColors.orange)),
        error: (err, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: AdminColors.danger, size: 48),
              const SizedBox(height: AppSpacing.md),
              Text('Failed to load dashboard data: $err', style: const TextStyle(color: AdminColors.textSecondary)),
              const SizedBox(height: AppSpacing.md),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AdminColors.orange),
                onPressed: () => ref.invalidate(adminDashboardStatsProvider),
                child: const Text('Retry', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final bool? isUp;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _StatCard({
    required this.label,
    required this.value,
    required this.sub,
    this.isUp,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
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
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isUp == true
                          ? AdminColors.successBg
                          : (isUp == false ? AdminColors.dangerBg : AdminColors.cardBorder),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isUp == true) const Icon(Icons.trending_up_rounded, color: AdminColors.success, size: 12),
                        if (isUp == false) const Icon(Icons.trending_down_rounded, color: AdminColors.danger, size: 12),
                        if (isUp != null) const SizedBox(width: 4),
                        Text(
                          sub,
                          style: TextStyle(
                            color: isUp == true
                                ? AdminColors.success
                                : (isUp == false ? AdminColors.danger : AdminColors.textSecondary),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      color: AdminColors.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: const TextStyle(color: AdminColors.textSecondary, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: AdminColors.cardBg,
        foregroundColor: AdminColors.textPrimary,
        side: const BorderSide(color: AdminColors.cardBorder),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: onTap,
      icon: Icon(icon, color: AdminColors.orange, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }
}
