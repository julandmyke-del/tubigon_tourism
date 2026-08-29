import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

enum StatusType {
  pending,
  confirmed,
  cancelled,
  completed,
  conflict,
  verified,
  active,
  inactive
}

/// Colored pill badge for status indicators.
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.status,
    this.compact = false,
  });

  final StatusType status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final config = _configs[status]!;
    return Container(
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 8, vertical: 3)
          : const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
      decoration: BoxDecoration(
        color: config.background,
        borderRadius: AppSpacing.roundedFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: config.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            config.label,
            style: AppTypography.labelSmall.copyWith(
              color: config.color,
              fontWeight: FontWeight.w600,
              fontSize: compact ? 10 : null,
            ),
          ),
        ],
      ),
    );
  }

  static const _configs = {
    StatusType.pending: _BadgeConfig(
      label: 'Pending',
      color: AppColors.warning,
      background: AppColors.warningContainer,
    ),
    StatusType.confirmed: _BadgeConfig(
      label: 'Confirmed',
      color: AppColors.success,
      background: AppColors.successContainer,
    ),
    StatusType.cancelled: _BadgeConfig(
      label: 'Cancelled',
      color: AppColors.error,
      background: AppColors.errorContainer,
    ),
    StatusType.completed: _BadgeConfig(
      label: 'Completed',
      color: AppColors.secondary,
      background: AppColors.secondaryContainer,
    ),
    StatusType.conflict: _BadgeConfig(
      label: 'Conflict',
      color: AppColors.error,
      background: AppColors.errorContainer,
    ),
    StatusType.verified: _BadgeConfig(
      label: 'Verified',
      color: AppColors.accent,
      background: AppColors.accentContainer,
    ),
    StatusType.active: _BadgeConfig(
      label: 'Active',
      color: AppColors.success,
      background: AppColors.successContainer,
    ),
    StatusType.inactive: _BadgeConfig(
      label: 'Inactive',
      color: AppColors.grey500,
      background: AppColors.grey100,
    ),
  };
}

class _BadgeConfig {
  const _BadgeConfig({
    required this.label,
    required this.color,
    required this.background,
  });
  final String label;
  final Color color;
  final Color background;
}
