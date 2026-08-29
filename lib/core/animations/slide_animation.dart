import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

enum SlideDirection { fromBottom, fromTop, fromLeft, fromRight }

/// Slide-in animation wrapper with configurable direction.
class SlideAnimation extends StatefulWidget {
  const SlideAnimation({
    super.key,
    required this.child,
    this.direction = SlideDirection.fromBottom,
    this.duration = AppConstants.animNormal,
    this.delay = Duration.zero,
    this.curve = Curves.easeOutCubic,
    this.offset = 0.2,
  });

  final Widget child;
  final SlideDirection direction;
  final Duration duration;
  final Duration delay;
  final Curve curve;

  /// Fractional offset (0.0–1.0) for the slide distance.
  final double offset;

  @override
  State<SlideAnimation> createState() => _SlideAnimationState();
}

class _SlideAnimationState extends State<SlideAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);

    final begin = switch (widget.direction) {
      SlideDirection.fromBottom => Offset(0, widget.offset),
      SlideDirection.fromTop => Offset(0, -widget.offset),
      SlideDirection.fromLeft => Offset(-widget.offset, 0),
      SlideDirection.fromRight => Offset(widget.offset, 0),
    };

    _slide = Tween<Offset>(begin: begin, end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: widget.curve),
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);

    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slide,
      child: FadeTransition(opacity: _opacity, child: widget.child),
    );
  }
}
