import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/authentication/auth_provider.dart';

enum _AuthPromptAction { signIn, register }

/// Returns true only for a signed-in account. Guest discovery remains available,
/// while account-owned actions are directed to the existing login experience.
Future<bool> requireSignedIn(
  BuildContext context,
  WidgetRef ref, {
  String? returnTo,
}) async {
  final auth = ref.read(authProvider);
  if (auth.isLoggedIn && auth.userId != null) return true;

  final action = await showDialog<_AuthPromptAction>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Sign in required'),
      content: const Text(
        'Create an account or sign in to make reservations, save synced favorites, submit reports, or access personalized features.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Continue Browsing'),
        ),
        OutlinedButton(
          onPressed: () =>
              Navigator.pop(dialogContext, _AuthPromptAction.register),
          child: const Text('Create Account'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.pop(dialogContext, _AuthPromptAction.signIn),
          child: const Text('Sign In'),
        ),
      ],
    ),
  );

  if (action != null && context.mounted) {
    final target = safeTouristReturnRoute(returnTo);
    final loginUri = Uri(
      path: action == _AuthPromptAction.register
          ? '/auth/login/register'
          : '/onboarding',
      queryParameters: {
        if (action == _AuthPromptAction.signIn) 'page': '5',
        if (action == _AuthPromptAction.signIn) 'login': 'true',
        if (target != null) 'returnTo': target,
      },
    );
    context.push(loginUri.toString());
  }
  return false;
}

/// Accepts only an internal Tourist route. This prevents an auth callback from
/// becoming an open redirect and keeps portal/admin routes role-authoritative.
String? safeTouristReturnRoute(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  final uri = Uri.tryParse(value.trim());
  if (uri == null ||
      uri.hasScheme ||
      uri.hasAuthority ||
      !uri.path.startsWith('/')) {
    return null;
  }
  const blockedPrefixes = <String>[
    '/admin',
    '/lgu',
    '/msme-portal',
    '/tourism-partner',
    '/auth',
    '/onboarding',
    '/splash',
  ];
  if (blockedPrefixes.any(uri.path.startsWith)) return null;
  return uri.toString();
}

Widget signedInRequiredPage(BuildContext context, WidgetRef ref,
    {required String title}) {
  return Scaffold(
    backgroundColor: const Color(0xFF080F1A),
    appBar: AppBar(
      backgroundColor: const Color(0xFF0F172A),
      foregroundColor: Colors.white,
      title: Text(title),
    ),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline_rounded,
                size: 60, color: Color(0xFF64748B)),
            const SizedBox(height: 16),
            Text('Sign in to access $title',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text(
                'You can continue browsing Explore, Map, ferry information, eco tips, and emergency contacts as a guest.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF94A3B8))),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => requireSignedIn(
                context,
                ref,
                returnTo: GoRouterState.of(context).uri.toString(),
              ),
              icon: const Icon(Icons.login_rounded),
              label: const Text('Sign in or create account'),
            ),
          ],
        ),
      ),
    ),
  );
}
