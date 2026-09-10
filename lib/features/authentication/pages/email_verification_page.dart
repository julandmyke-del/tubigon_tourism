import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/gradient_button.dart';
import '../auth_provider.dart';

class EmailVerificationPage extends ConsumerStatefulWidget {
  const EmailVerificationPage({
    super.key,
    required this.email,
    this.returnTo,
  });

  final String email;
  final String? returnTo;

  @override
  ConsumerState<EmailVerificationPage> createState() =>
      _EmailVerificationPageState();
}

class _EmailVerificationPageState extends ConsumerState<EmailVerificationPage> {
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _codeFocus = FocusNode();
  Timer? _ticker;
  late String _email;
  EmailVerificationContext? _verification;
  int _expiresInSeconds = 0;
  int _resendInSeconds = 0;
  bool _isLoadingContext = true;
  bool _isVerifying = false;
  bool _isResending = false;
  bool _isSuccess = false;
  String? _inlineError;

  @override
  void initState() {
    super.initState();
    _email = widget.email.trim();
    _codeController.addListener(_handleCodeChanged);
    _codeFocus.addListener(_handleFocusChanged);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadVerificationContext();
      if (mounted) _codeFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _codeController
      ..removeListener(_handleCodeChanged)
      ..dispose();
    _codeFocus
      ..removeListener(_handleFocusChanged)
      ..dispose();
    super.dispose();
  }

  void _handleCodeChanged() {
    if (!mounted) return;
    setState(() => _inlineError = null);
  }

  void _handleFocusChanged() {
    if (mounted) setState(() {});
  }

  void _tick() {
    if (!mounted || (_expiresInSeconds <= 0 && _resendInSeconds <= 0)) return;
    setState(() {
      if (_expiresInSeconds > 0) _expiresInSeconds--;
      if (_resendInSeconds > 0) _resendInSeconds--;
    });
  }

  Future<void> _loadVerificationContext() async {
    if (_email.isEmpty) {
      if (mounted) context.go('/onboarding?page=5&login=true');
      return;
    }

    try {
      final value = await ref
          .read(authProvider.notifier)
          .getEmailVerificationContext(_email);
      if (mounted) _applyVerificationContext(value);
    } catch (_) {
      if (mounted) {
        setState(() {
          _inlineError =
              'Unable to load verification status. Check your connection.';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoadingContext = false);
    }
  }

  void _applyVerificationContext(EmailVerificationContext value) {
    setState(() {
      _verification = value;
      _email = value.email;
      _expiresInSeconds = value.expiresInSeconds;
      _resendInSeconds = value.resendAvailableInSeconds;
    });
  }

  Future<void> _verifyCode() async {
    final code = _codeController.text;
    if (_isVerifying || code.length != 6) return;

    setState(() {
      _isVerifying = true;
      _inlineError = null;
    });

    try {
      final pendingSession =
          await ref.read(authProvider.notifier).verifyEmailCode(
                email: _email,
                code: code,
              );
      if (!mounted) return;
      setState(() => _isSuccess = true);
      await Future<void>.delayed(const Duration(milliseconds: 550));
      if (!mounted) return;
      await ref
          .read(authProvider.notifier)
          .completeVerifiedEmailSession(pendingSession);
      if (mounted) {
        context.go(widget.returnTo ?? ref.read(authProvider).homeRoute);
      }
    } on VerificationCodeException catch (error) {
      if (!mounted) return;
      _applyVerificationContext(error.context);
      _codeController.clear();
      setState(() => _inlineError = error.message);
      _codeFocus.requestFocus();
    } catch (error) {
      if (mounted) {
        setState(() {
          _inlineError = error.toString().replaceAll('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _resendCode() async {
    if (_isResending || _resendInSeconds > 0) return;
    setState(() {
      _isResending = true;
      _inlineError = null;
    });

    try {
      final value =
          await ref.read(authProvider.notifier).resendVerificationEmail(_email);
      if (!mounted) return;
      _applyVerificationContext(value);
      _codeController.clear();
      _codeFocus.requestFocus();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A new verification code was sent.'),
          backgroundColor: AppColors.successContainer,
        ),
      );
    } on VerificationCodeException catch (error) {
      if (!mounted) return;
      _applyVerificationContext(error.context);
      setState(() => _inlineError = error.message);
    } catch (error) {
      if (mounted) {
        setState(() {
          _inlineError = error.toString().replaceAll('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _changeEmail() async {
    final formKey = GlobalKey<FormState>();
    final emailController = TextEditingController(text: _email);
    final passwordController = TextEditingController();
    EmailVerificationContext? result;

    try {
      result = await showDialog<EmailVerificationContext>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          bool saving = false;
          String? dialogError;
          return StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              title: const Text('Change verification email'),
              content: SizedBox(
                width: 420,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Confirm your account password to update this pending signup without creating another account.',
                        style: GoogleFonts.inter(
                          color: AppColors.grey300,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: emailController,
                        enabled: !saving,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'New email address',
                          prefixIcon: Icon(Icons.alternate_email_rounded),
                        ),
                        validator: (value) {
                          final email = value?.trim() ?? '';
                          if (!email.contains('@') || email == _email) {
                            return 'Enter a different valid email address.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: passwordController,
                        enabled: !saving,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Current password',
                          prefixIcon: Icon(Icons.lock_outline_rounded),
                        ),
                        validator: (value) => (value?.isEmpty ?? true)
                            ? 'Enter your account password.'
                            : null,
                      ),
                      if (dialogError != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          dialogError!,
                          style: GoogleFonts.inter(
                            color: AppColors.error,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      saving ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Keep current email'),
                ),
                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (!(formKey.currentState?.validate() ?? false)) {
                            return;
                          }
                          setDialogState(() {
                            saving = true;
                            dialogError = null;
                          });
                          try {
                            final value = await ref
                                .read(authProvider.notifier)
                                .changeUnverifiedEmail(
                                  email: _email,
                                  password: passwordController.text,
                                  newEmail: emailController.text,
                                );
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop(value);
                            }
                          } catch (error) {
                            if (dialogContext.mounted) {
                              setDialogState(() {
                                saving = false;
                                dialogError = error
                                    .toString()
                                    .replaceAll('Exception: ', '');
                              });
                            }
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Update & send code'),
                ),
              ],
            ),
          );
        },
      );
    } finally {
      emailController.dispose();
      passwordController.dispose();
    }

    if (result != null && mounted) {
      _applyVerificationContext(result);
      _codeController.clear();
      _codeFocus.requestFocus();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email updated. Enter the new code we sent.'),
          backgroundColor: AppColors.successContainer,
        ),
      );
    }
  }

  String _maskEmail(String email) {
    final at = email.indexOf('@');
    if (at <= 0) return email;
    final local = email.substring(0, at);
    final domain = email.substring(at + 1);
    final visible =
        local.length <= 2 ? local.substring(0, 1) : local.substring(0, 2);
    return '$visible***@$domain';
  }

  String _clock(int seconds) {
    final safeSeconds = seconds.clamp(0, 359999);
    final minutes = safeSeconds ~/ 60;
    final remainder = safeSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainder.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final verification = _verification;
    final attemptsExhausted = verification != null &&
        verification.attemptsUsed >= verification.maxAttempts;
    final canVerify = _codeController.text.length == 6 &&
        !_isVerifying &&
        !_isSuccess &&
        (verification == null || _expiresInSeconds > 0) &&
        !attemptsExhausted;

    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: Stack(
        children: [
          const Positioned.fill(child: _TubigonAuthBackground()),
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg + viewInsets.bottom,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.sizeOf(context).height -
                      MediaQuery.paddingOf(context).vertical -
                      (AppSpacing.lg * 2),
                ),
                child: Center(
                  child: ClipRRect(
                    borderRadius: AppSpacing.roundedXxl,
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: double.infinity,
                        constraints: const BoxConstraints(maxWidth: 500),
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color.fromRGBO(39, 49, 63, 0.94),
                              Color.fromRGBO(18, 30, 48, 0.97),
                            ],
                          ),
                          borderRadius: AppSpacing.roundedXxl,
                          border: Border.all(color: AppColors.lightOutline),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x66000000),
                              blurRadius: 36,
                              offset: Offset(0, 16),
                            ),
                          ],
                        ),
                        child: _isSuccess
                            ? const _VerificationSuccess()
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _VerificationIcon(
                                    hasError: _inlineError != null,
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  Text(
                                    'Verify Your Email',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.plusJakartaSans(
                                      color: AppColors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  Text(
                                    'Enter the 6-digit code we sent to',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.inter(
                                      color: AppColors.grey300,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    _maskEmail(_email),
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.outfit(
                                      color: AppColors.accentLight,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.lg),
                                  _OtpInput(
                                    controller: _codeController,
                                    focusNode: _codeFocus,
                                    hasError: _inlineError != null,
                                    enabled: !_isVerifying,
                                  ),
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 180),
                                    child: _inlineError == null
                                        ? const SizedBox(
                                            height: AppSpacing.md,
                                          )
                                        : Container(
                                            key: ValueKey(_inlineError),
                                            width: double.infinity,
                                            margin: const EdgeInsets.only(
                                              top: AppSpacing.md,
                                            ),
                                            padding: const EdgeInsets.all(
                                              AppSpacing.sm,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.errorContainer
                                                  .withValues(alpha: 0.48),
                                              borderRadius:
                                                  AppSpacing.roundedMd,
                                              border: Border.all(
                                                color: AppColors.error
                                                    .withValues(alpha: 0.55),
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(
                                                  Icons.error_outline_rounded,
                                                  color: AppColors.error,
                                                  size: 18,
                                                ),
                                                const SizedBox(
                                                  width: AppSpacing.sm,
                                                ),
                                                Expanded(
                                                  child: Text(
                                                    _inlineError!,
                                                    style: GoogleFonts.inter(
                                                      color: AppColors.grey100,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                  ),
                                  TextButton(
                                    key: const ValueKey(
                                      'change_email_button',
                                    ),
                                    onPressed:
                                        _isVerifying ? null : _changeEmail,
                                    child: Text.rich(
                                      TextSpan(
                                        text: 'Not your email? ',
                                        style: GoogleFonts.inter(
                                          color: AppColors.grey400,
                                          fontSize: 12,
                                        ),
                                        children: const [
                                          TextSpan(
                                            text: 'Change it',
                                            style: TextStyle(
                                              color: AppColors.accent,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  Text(
                                    "Didn't receive the code?\nCheck your spam folder or resend it.",
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.inter(
                                      color: AppColors.grey400,
                                      fontSize: 12,
                                      height: 1.45,
                                    ),
                                  ),
                                  TextButton(
                                    key: const ValueKey(
                                      'resend_code_button',
                                    ),
                                    onPressed:
                                        _resendInSeconds == 0 && !_isResending
                                            ? _resendCode
                                            : null,
                                    child: _isResending
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: AppColors.accent,
                                            ),
                                          )
                                        : Text(
                                            _resendInSeconds > 0
                                                ? 'Resend code in ${_clock(_resendInSeconds)}'
                                                : 'Resend Code',
                                            style: GoogleFonts.outfit(
                                              color: _resendInSeconds > 0
                                                  ? AppColors.grey500
                                                  : AppColors.accent,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  GradientButton(
                                    key: const ValueKey(
                                      'verify_email_button',
                                    ),
                                    label: 'VERIFY EMAIL',
                                    onPressed: canVerify ? _verifyCode : null,
                                    isEnabled: canVerify,
                                    isLoading: _isVerifying,
                                    gradient: const LinearGradient(
                                      colors: [
                                        AppColors.accent,
                                        Color(0xFFF97316),
                                      ],
                                    ),
                                    icon: const Icon(
                                      Icons.arrow_forward_rounded,
                                      color: AppColors.white,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  TextButton(
                                    key: const ValueKey(
                                      'cancel_verification_button',
                                    ),
                                    onPressed: _isVerifying
                                        ? null
                                        : () => context.go(
                                              '/onboarding?page=5&login=true',
                                            ),
                                    child: Text(
                                      'Cancel',
                                      style: GoogleFonts.outfit(
                                        color: AppColors.grey300,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const Divider(),
                                  if (_isLoadingContext)
                                    const SizedBox(
                                      height: 16,
                                      width: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.accent,
                                      ),
                                    )
                                  else if (verification != null)
                                    Text(
                                      '${verification.attemptsUsed}/${verification.maxAttempts} attempts  •  '
                                      '${_expiresInSeconds > 0 ? 'Code expires in ${_clock(_expiresInSeconds)}' : 'Code expired'}',
                                      key: const ValueKey(
                                        'verification_status_footer',
                                      ),
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.inter(
                                        color: _expiresInSeconds > 0
                                            ? AppColors.grey400
                                            : AppColors.warning,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TubigonAuthBackground extends StatelessWidget {
  const _TubigonAuthBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryDark,
            AppColors.primary,
            AppColors.secondaryDark,
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -100,
            right: -80,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent.withValues(alpha: 0.10),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.16),
                    blurRadius: 100,
                    spreadRadius: 24,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: -120,
            left: -90,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryLight.withValues(alpha: 0.35),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VerificationIcon extends StatelessWidget {
  const _VerificationIcon({required this.hasError});

  final bool hasError;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: hasError
              ? [AppColors.error, AppColors.errorContainer]
              : [AppColors.accent, const Color(0xFFF97316)],
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: (hasError ? AppColors.error : AppColors.accent)
                .withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Icon(
        hasError ? Icons.mark_email_unread_rounded : Icons.mail_lock_rounded,
        color: AppColors.white,
        size: 34,
      ),
    );
  }
}

class _OtpInput extends StatelessWidget {
  const _OtpInput({
    required this.controller,
    required this.focusNode,
    required this.hasError,
    required this.enabled,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasError;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      textField: true,
      label: 'Six digit email verification code',
      child: GestureDetector(
        onTap: enabled ? focusNode.requestFocus : null,
        child: SizedBox(
          height: 58,
          child: Stack(
            children: [
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    const gap = 8.0;
                    final boxWidth = ((constraints.maxWidth - (gap * 5)) / 6)
                        .clamp(38.0, 54.0);
                    final digits = controller.text.split('');
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(6, (index) {
                        final filled = index < digits.length;
                        final focused = focusNode.hasFocus &&
                            index == (digits.length >= 6 ? 5 : digits.length);
                        final borderColor = hasError
                            ? AppColors.error
                            : focused
                                ? AppColors.accent
                                : AppColors.lightOutline;
                        return Padding(
                          padding: EdgeInsets.only(right: index == 5 ? 0 : gap),
                          child: AnimatedContainer(
                            key: ValueKey('otp_digit_$index'),
                            duration: const Duration(milliseconds: 140),
                            width: boxWidth,
                            height: 56,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: filled
                                  ? AppColors.accent.withValues(alpha: 0.10)
                                  : AppColors.surfaceDark,
                              borderRadius: AppSpacing.roundedMd,
                              border: Border.all(
                                color: borderColor,
                                width: focused || hasError ? 1.6 : 1,
                              ),
                              boxShadow: focused
                                  ? [
                                      BoxShadow(
                                        color: AppColors.accent
                                            .withValues(alpha: 0.16),
                                        blurRadius: 10,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Text(
                              filled ? digits[index] : '',
                              style: GoogleFonts.outfit(
                                color: AppColors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        );
                      }),
                    );
                  },
                ),
              ),
              Positioned.fill(
                child: Opacity(
                  opacity: 0.01,
                  child: TextField(
                    key: const ValueKey('otp_text_field'),
                    controller: controller,
                    focusNode: focusNode,
                    enabled: enabled,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    enableSuggestions: false,
                    autocorrect: false,
                    maxLength: 6,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    onSubmitted: (_) {},
                    decoration: const InputDecoration(
                      counterText: '',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      fillColor: Colors.transparent,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VerificationSuccess extends StatelessWidget {
  const _VerificationSuccess();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: AppColors.successContainer,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.success, width: 2),
            ),
            child: const Icon(
              Icons.check_rounded,
              color: AppColors.success,
              size: 42,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Email verified successfully',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              color: AppColors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Opening your Tubigon Tourist home…',
            style: GoogleFonts.inter(
              color: AppColors.grey300,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
