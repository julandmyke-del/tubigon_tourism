import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/connectivity_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// One app-wide, non-modal connectivity notice. It remains visible offline and
/// shows one short recovery message when connectivity returns.
class OfflineBanner extends ConsumerStatefulWidget {
  const OfflineBanner({super.key});

  @override
  ConsumerState<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends ConsumerState<OfflineBanner> {
  ConnectivityStatus? _lastStatus;
  bool _showBackOnline = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<ConnectivityStatus>>(connectivityProvider,
        (previous, next) {
      final status = next.valueOrNull;
      if (status == null || status == _lastStatus) return;
      final wasOffline = _lastStatus == ConnectivityStatus.offline ||
          previous?.valueOrNull == ConnectivityStatus.offline;
      _lastStatus = status;
      if (status == ConnectivityStatus.online && wasOffline) {
        _timer?.cancel();
        if (mounted) setState(() => _showBackOnline = true);
        _timer = Timer(const Duration(seconds: 3), () {
          if (mounted) setState(() => _showBackOnline = false);
        });
      } else if (status == ConnectivityStatus.offline && _showBackOnline) {
        _timer?.cancel();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _showBackOnline = false);
        });
      }
    });

    final isOffline = ref.watch(connectivityProvider).valueOrNull ==
        ConnectivityStatus.offline;
    final visible = isOffline || _showBackOnline;
    return IgnorePointer(
      child: SafeArea(
        bottom: false,
        child: AnimatedSlide(
          offset: visible ? Offset.zero : const Offset(0, -1.5),
          duration: const Duration(milliseconds: 300),
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: const Duration(milliseconds: 250),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: isOffline ? AppColors.warning : const Color(0xFF047857),
              child: Row(children: [
                Icon(isOffline ? Icons.wifi_off_rounded : Icons.wifi_rounded,
                    color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isOffline
                        ? 'Offline mode — showing saved information. Some information may be outdated.'
                        : 'Back online — refreshing saved information.',
                    style:
                        AppTypography.bodySmall.copyWith(color: Colors.white),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
