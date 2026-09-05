import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubigon_tourism/features/authentication/auth_provider.dart';
import 'package:tubigon_tourism/features/authentication/pages/reset_password_page.dart';

class _ResetAuthNotifier extends AuthNotifier {
  static Completer<void>? pending;
  static int submissions = 0;

  @override
  AuthState build() => const AuthState();

  @override
  Future<void> completePasswordReset({
    required String email,
    required String token,
    required String password,
  }) {
    submissions++;
    return pending?.future ?? Future.value();
  }
}

Widget _app() => ProviderScope(
      overrides: [authProvider.overrideWith(_ResetAuthNotifier.new)],
      child: const MaterialApp(
        home: ResetPasswordPage(
          token: 'valid-token',
          email: 'tourist@example.test',
        ),
      ),
    );

void main() {
  testWidgets('password reset validates and prevents duplicate submissions',
      (tester) async {
    _ResetAuthNotifier.pending = Completer<void>();
    _ResetAuthNotifier.submissions = 0;
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'new-safe-password');
    await tester.enterText(fields.at(1), 'new-safe-password');
    await tester.tap(find.widgetWithText(FilledButton, 'Reset Password'));
    await tester.pump();

    expect(_ResetAuthNotifier.submissions, 1);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);

    _ResetAuthNotifier.pending!.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(_ResetAuthNotifier.submissions, 1);
    expect(find.text('Password reset complete'), findsOneWidget);
  });
}
