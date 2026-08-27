import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../network/connectivity_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Animated banner that slides in when offline and slides out when online.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(connectivityProvider);

    final isOffline = status.when(
      data: (s) => s == ConnectivityStatus.offline,
      loading: () => false,
      error: (_, __) => false,
    );

    return AnimatedSlide(
      offset: isOffline ? Offset.zero : const Offset(0, -1),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      child: AnimatedOpacity(
        opacity: isOffline ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 350),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          decoration: const BoxDecoration(
            color: AppColors.warning,
          ),
          child: Row(
            children: [
              const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Text(
                'You are offline. Some features may be limited.',
                style: AppTypography.bodySmall.copyWith(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
