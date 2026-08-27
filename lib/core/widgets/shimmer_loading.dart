import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Skeleton shimmer loader that matches the layout of any widget placeholder.
class ShimmerLoading extends StatelessWidget {
  const ShimmerLoading({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? AppColors.darkSurfaceVariant : AppColors.shimmerBase,
      highlightColor:
          isDark ? AppColors.darkOutline : AppColors.shimmerHighlight,
      child: child,
    );
  }
}

/// A rectangular shimmer placeholder block.
class ShimmerBox extends StatelessWidget {
  const ShimmerBox({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius,
  });

  final double? width;
  final double height;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            borderRadius ?? BorderRadius.circular(AppSpacing.radiusSm),
      ),
    );
  }
}

/// Pre-built shimmer layout for a tourist spot card.
class SpotCardShimmer extends StatelessWidget {
  const SpotCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Container(
        height: 260,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image placeholder
            Container(
              height: 160,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(AppSpacing.radiusXl),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(width: 160, height: 16),
                  SizedBox(height: AppSpacing.xs),
                  ShimmerBox(width: 100, height: 12),
                  SizedBox(height: AppSpacing.sm),
                  ShimmerBox(width: 80, height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shimmer layout for a list tile (e.g., ferry schedule row).
class ListTileShimmer extends StatelessWidget {
  const ListTileShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(height: 14),
                  SizedBox(height: 6),
                  ShimmerBox(width: 120, height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
