import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_gradients.dart';
import '../theme/app_typography.dart';
import '../theme/app_spacing.dart';

/// A premium gradient button with loading, disabled, and pressed states.
class GradientButton extends StatefulWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.gradient,
    this.icon,
    this.isLoading = false,
    this.isEnabled = true,
    this.height = AppSpacing.buttonHeight,
    this.width,
    this.borderRadius,
    this.textStyle,
    this.padding,
  });

  final String label;
  final VoidCallback? onPressed;
  final Gradient? gradient;
  final Widget? icon;
  final bool isLoading;
  final bool isEnabled;
  final double height;
  final double? width;
  final BorderRadius? borderRadius;
  final TextStyle? textStyle;
  final EdgeInsets? padding;

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isActive => widget.isEnabled && !widget.isLoading && widget.onPressed != null;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _isActive ? (_) => _controller.forward() : null,
      onTapUp: _isActive
          ? (_) {
              _controller.reverse();
              widget.onPressed?.call();
            }
          : null,
      onTapCancel: _isActive ? () => _controller.reverse() : null,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: widget.height,
          width: widget.width ?? double.infinity,
          decoration: BoxDecoration(
            gradient: _isActive
                ? (widget.gradient ?? AppGradients.primary)
                : null,
            color: _isActive ? null : AppColors.grey300,
            borderRadius:
                widget.borderRadius ?? BorderRadius.circular(AppSpacing.radiusLg),
            boxShadow: _isActive
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ]
                : null,
          ),
          child: Center(
            child: widget.isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppColors.white),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.icon != null) ...[
                        widget.icon!,
                        const SizedBox(width: AppSpacing.sm),
                      ],
                      Text(
                        widget.label,
                        style: (widget.textStyle ?? AppTypography.buttonText).copyWith(
                          color: _isActive ? AppColors.white : AppColors.grey500,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
