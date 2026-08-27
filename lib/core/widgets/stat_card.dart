import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Animated statistics card for dashboard numbers.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    String? title,
    String? label,
    required this.value,
    required this.icon,
    this.subtitle,
    this.color,
    this.onTap,
    this.trend,
  }) : label = title ?? label ?? '';

  final String label;
  final String value;
  final IconData icon;
  final String? subtitle;
  final Color? color;
  final VoidCallback? onTap;
  final StatTrend? trend;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = color ?? AppColors.primary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.white,
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          border: Border.all(
            color: isDark ? AppColors.darkOutline : AppColors.lightOutline,
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: Icon(icon, color: accentColor, size: 20),
                ),
                const Spacer(),
                if (trend != null) _TrendBadge(trend: trend!),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              value,
              style: AppTypography.headlineMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTypography.bodySmall.copyWith(color: AppColors.grey500),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: AppTypography.labelSmall.copyWith(color: AppColors.grey400),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class StatTrend {
  const StatTrend({required this.percent, required this.isPositive});
  final double percent;
  final bool isPositive;
}

class _TrendBadge extends StatelessWidget {
  const _TrendBadge({required this.trend});
  final StatTrend trend;

  @override
  Widget build(BuildContext context) {
    final color = trend.isPositive ? AppColors.success : AppColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            trend.isPositive
                ? Icons.trending_up_rounded
                : Icons.trending_down_rounded,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 2),
          Text(
            '${trend.percent.toStringAsFixed(1)}%',
            style: AppTypography.labelSmall.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
