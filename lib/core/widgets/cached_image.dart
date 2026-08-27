import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'shimmer_loading.dart';

/// Wrapper around [CachedNetworkImage] with shimmer placeholder and error fallback.
class CachedImage extends StatelessWidget {
  const CachedImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
  });

  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;

  @override
  Widget build(BuildContext context) {
    final fallbackPlaceholder = placeholder ??
        ShimmerLoading(
          child: Container(
            width: width,
            height: height,
            color: Colors.white,
          ),
        );

    final fallbackError = errorWidget ??
        Container(
          width: width,
          height: height,
          color: AppColors.grey100,
          child: const Icon(
            Icons.image_not_supported_rounded,
            color: AppColors.grey400,
            size: AppSpacing.iconLg,
          ),
        );

    if (url == null || url!.isEmpty) {
      return ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.zero,
        child: fallbackError,
      );
    }

    Widget image = CachedNetworkImage(
      imageUrl: url!,
      width: width,
      height: height,
      fit: fit,
      placeholder: (_, __) => fallbackPlaceholder,
      errorWidget: (_, __, ___) => fallbackError,
    );

    if (borderRadius != null) {
      image = ClipRRect(borderRadius: borderRadius!, child: image);
    }

    return image;
  }
}
