import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../auth_provider.dart';

class EmailVerificationPage extends ConsumerStatefulWidget {
  final String email;

  const EmailVerificationPage({
    super.key,
    required this.email,
  });

  @override
  ConsumerState<EmailVerificationPage> createState() =>
      _EmailVerificationPageState();
}

class _EmailVerificationPageState extends ConsumerState<EmailVerificationPage> {
  static const int _cooldownDuration = 60;
  int _cooldownRemaining = 0;
  Timer? _cooldownTimer;
  Timer? _pollTimer;
  bool _isResending = false;
  bool _isCheckingStatus = false;
  bool _isVerified = false;

  @override
  void initState() {
    super.initState();
    _startCooldownTimer();
    _startPolling();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  void _startCooldownTimer() {
    setState(() => _cooldownRemaining = _cooldownDuration);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldownRemaining > 0) {
        setState(() => _cooldownRemaining--);
      } else {
        timer.cancel();
      }
    });
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkStatusSilently();
    });
  }

  Future<void> _checkStatusSilently() async {
    if (_isVerified || _isCheckingStatus || widget.email.isEmpty) return;
    _isCheckingStatus = true;
    try {
      final verified = await ref
          .read(authProvider.notifier)
          .checkVerificationStatus(widget.email);
      if (verified && mounted) {
        setState(() {
          _isVerified = true;
        });
        _pollTimer?.cancel();
        _showVerifiedSuccessDialog();
      }
    } catch (_) {
    } finally {
      _isCheckingStatus = false;
    }
  }

  Future<void> _resendVerificationEmail() async {
    if (_cooldownRemaining > 0 || _isResending) return;

    setState(() => _isResending = true);
    try {
      final message = await ref
          .read(authProvider.notifier)
          .resendVerificationEmail(widget.email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: GoogleFonts.inter(color: Colors.white),
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      _startCooldownTimer();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to send email: ${e.toString().replaceAll('Exception: ', '')}',
            style: GoogleFonts.inter(color: Colors.white),
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  void _showVerifiedSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C2541),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: Color(0xFF22C55E), size: 28),
            const SizedBox(width: 10),
            Text(
              'Email Verified!',
              style: GoogleFonts.plusJakartaSans(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Your account is now active. You can log in with your credentials.',
          style: GoogleFonts.inter(color: const Color(0xFF94A3B8)),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF97316),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              context.go('/onboarding?page=5&login=true');
            },
            child: const Text('Proceed to Login',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  String _maskEmail(String email) {
    if (!email.contains('@')) return email;
    final parts = email.split('@');
    final name = parts[0];
    final domain = parts[1];

    if (name.length <= 2) {
      return '${name[0]}***@$domain';
    }
    return '${name[0]}***${name[name.length - 1]}@$domain';
  }

  @override
  Widget build(BuildContext context) {
    final maskedEmail = _maskEmail(widget.email);

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 480),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(24),
                border:
                    Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 30,
                    offset: Offset(0, 15),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon Header
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.4)),
                    ),
                    child: const Icon(
                      Icons.mark_email_unread_rounded,
                      color: AppColors.accent,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Title
                  Text(
                    'Verify Your Email Address',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),

                  // Subtitle & Instructions
                  Text(
                    'We have sent a verification link to your registered email address:',
                    style: GoogleFonts.inter(
                        fontSize: 13, color: AppColors.grey400),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),

                  // Masked Email Pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.email_outlined,
                            color: AppColors.accent, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          maskedEmail,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Status Badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: _isVerified
                          ? AppColors.successContainer
                          : AppColors.warningContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _isVerified
                                ? AppColors.success
                                : AppColors.warning,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isVerified ? 'VERIFIED' : 'PENDING VERIFICATION',
                          style: GoogleFonts.inter(
                            color: _isVerified
                                ? AppColors.success
                                : AppColors.warning,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  const Divider(color: AppColors.lightOutline),
                  const SizedBox(height: AppSpacing.md),

                  // Verification Guidance
                  Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          color: AppColors.grey400, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Open your email inbox (or spam folder) and click the verification link to activate your account.',
                          style: GoogleFonts.inter(
                              fontSize: 12, color: AppColors.grey400),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Resend Verification Email Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _cooldownRemaining > 0
                            ? AppColors.secondary
                            : AppColors.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _cooldownRemaining > 0 || _isResending
                          ? null
                          : _resendVerificationEmail,
                      icon: _isResending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send_rounded, size: 18),
                      label: Text(
                        _cooldownRemaining > 0
                            ? 'Resend Email in (${_cooldownRemaining}s)'
                            : 'Resend Verification Email',
                        style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Manual Check Button
                  TextButton.icon(
                    onPressed: _isCheckingStatus ? null : _checkStatusSilently,
                    icon: _isCheckingStatus
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.grey400))
                        : const Icon(Icons.refresh_rounded,
                            color: AppColors.grey400, size: 16),
                    label: Text(
                      'I have verified, check status',
                      style: GoogleFonts.inter(
                          color: AppColors.grey400, fontSize: 13),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.sm),

                  // Back to Login Button
                  TextButton(
                    onPressed: () =>
                        context.go('/onboarding?page=5&login=true'),
                    child: Text(
                      '← Back to Login',
                      style: GoogleFonts.inter(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
