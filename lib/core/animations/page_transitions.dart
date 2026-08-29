import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_constants.dart';

/// Custom page transitions for GoRouter.
class AppPageTransitions {
  /// Fade transition (default for most pages).
  static CustomTransitionPage<T> fade<T>({
    required LocalKey key,
    required Widget child,
  }) {
    return CustomTransitionPage<T>(
      key: key,
      child: child,
      transitionDuration: AppConstants.animPageTransition,
      reverseTransitionDuration: AppConstants.animNormal,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          ),
          child: child,
        );
      },
    );
  }

  /// Slide-up transition (for bottom sheets / detail pages).
  static CustomTransitionPage<T> slideUp<T>({
    required LocalKey key,
    required Widget child,
  }) {
    return CustomTransitionPage<T>(
      key: key,
      child: child,
      transitionDuration: AppConstants.animPageTransition,
      reverseTransitionDuration: AppConstants.animNormal,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final slideAnim = Tween<Offset>(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));

        return SlideTransition(
          position: slideAnim,
          child: FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          ),
        );
      },
    );
  }

  /// Slide-right transition (for nested navigation).
  static CustomTransitionPage<T> slideRight<T>({
    required LocalKey key,
    required Widget child,
  }) {
    return CustomTransitionPage<T>(
      key: key,
      child: child,
      transitionDuration: AppConstants.animPageTransition,
      reverseTransitionDuration: AppConstants.animNormal,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final slideAnim = Tween<Offset>(
          begin: const Offset(1.0, 0),
          end: Offset.zero,
        ).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));

        final secondarySlide = Tween<Offset>(
          begin: Offset.zero,
          end: const Offset(-0.25, 0),
        ).animate(CurvedAnimation(
            parent: secondaryAnimation, curve: Curves.easeOutCubic));

        return SlideTransition(
          position: secondarySlide,
          child: SlideTransition(
            position: slideAnim,
            child: child,
          ),
        );
      },
    );
  }
}
