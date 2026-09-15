import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/exceptions/app_exception.dart';
import '../msme_theme.dart';

class MsmeSetupRequired extends StatelessWidget {
  const MsmeSetupRequired({
    super.key,
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: MsmeTheme.cardDecoration(),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.storefront_rounded,
                    size: 58, color: MsmeTheme.primaryOrange),
                const SizedBox(height: 16),
                Text(title,
                    textAlign: TextAlign.center,
                    style: MsmeTheme.headingLarge()),
                const SizedBox(height: 10),
                Text(message,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: MsmeTheme.textMuted)),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => context.go('/msme-portal/profile'),
                  icon: const Icon(Icons.add_business_rounded),
                  label: const Text('Set Up Business'),
                ),
              ]),
            ),
          ),
        ),
      );
}

class MsmePortalErrorState extends StatelessWidget {
  const MsmePortalErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_rounded,
                size: 48, color: MsmeTheme.primaryOrange),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(color: MsmeTheme.textMuted)),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ]),
        ),
      );
}

String friendlyMsmeError(Object error, String fallback) {
  if (error is AuthException && error.statusCode == 403) {
    return 'You do not have permission to access this feature.';
  }
  if (error is AppException) return error.message;
  final value = error.toString().toLowerCase();
  if (value.contains('no query results') ||
      value.contains('app\\models') ||
      value.contains('sqlstate') ||
      value.contains('serverexception')) {
    return fallback;
  }
  return error.toString().replaceFirst(RegExp(r'^[^:]+Exception:\s*'), '');
}
