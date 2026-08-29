import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_gradients.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'gradient_button.dart';

/// Beautiful empty state with illustration area, title, message, and action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.illustration,
    this.actionLabel,
    this.onAction,
    this.icon,
  });

  final String title;
  final String message;
  final Widget? illustration;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (illustration != null) ...[
              illustration!,
              const SizedBox(height: AppSpacing.xl),
            ] else ...[
              Container(
                width: 100,
                height: 100,
                decoration: const BoxDecoration(
                  gradient: AppGradients.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon ?? Icons.search_off_rounded,
                  size: 48,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
            Text(
              title,
              style: AppTypography.headlineSmall.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.grey500,
              ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: 180,
                child: GradientButton(
                  label: actionLabel!,
                  onPressed: onAction,
                  height: 48,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
