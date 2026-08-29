import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tubigon_tourism/core/theme/app_theme.dart';
import 'package:tubigon_tourism/core/widgets/gradient_button.dart';
import 'package:tubigon_tourism/features/authentication/auth_provider.dart';
import 'package:tubigon_tourism/features/authentication/pages/email_verification_page.dart';

class _FakeAuthNotifier extends AuthNotifier {
  static const initialContext = EmailVerificationContext(
    email: 'tourist@example.com',
    attemptsUsed: 1,
    maxAttempts: 5,
    expiresInSeconds: 512,
    resendAvailableInSeconds: 42,
    codeSent: true,
  );

  @override
  AuthState build() => const AuthState();

  @override
  Future<EmailVerificationContext> getEmailVerificationContext(
    String email,
  ) async =>
      initialContext;

  @override
  Future<VerifiedEmailSession> verifyEmailCode({
    required String email,
    required String code,
  }) {
    throw const VerificationCodeException(
      'The verification code is incorrect.',
      EmailVerificationContext(
        email: 'tourist@example.com',
        attemptsUsed: 2,
        maxAttempts: 5,
        expiresInSeconds: 500,
        resendAvailableInSeconds: 30,
        codeSent: true,
      ),
    );
  }
}

Widget _app() {
  return ProviderScope(
    overrides: [authProvider.overrideWith(_FakeAuthNotifier.new)],
    child: MaterialApp(
      theme: AppTheme.dark,
      home: const EmailVerificationPage(email: 'tourist@example.com'),
    ),
  );
}

void main() {
  testWidgets('OTP card is responsive and uses six paste-safe digit boxes',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Verify Your Email'), findsOneWidget);
    expect(find.text('to***@example.com'), findsOneWidget);
    for (var index = 0; index < 6; index++) {
      expect(find.byKey(ValueKey('otp_digit_$index')), findsOneWidget);
    }

    await tester.enterText(
      find.byKey(const ValueKey('otp_text_field')),
      '123456',
    );
    await tester.pump();

    for (final digit in '123456'.split('')) {
      expect(find.text(digit), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('wrong code uses inline themed error and server attempt state',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(
      find.byKey(const ValueKey('otp_text_field')),
      '123456',
    );
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const ValueKey('verify_email_button')),
    );
    final button = tester.widget<GradientButton>(
      find.byKey(const ValueKey('verify_email_button')),
    );
    expect(button.isEnabled, isTrue);
    button.onPressed?.call();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('The verification code is incorrect.'), findsOneWidget);
    expect(find.textContaining('2/5 attempts'), findsOneWidget);
    expect(find.byKey(const ValueKey('change_email_button')), findsOneWidget);
    expect(find.byKey(const ValueKey('resend_code_button')), findsOneWidget);
    expect(find.byKey(const ValueKey('cancel_verification_button')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
