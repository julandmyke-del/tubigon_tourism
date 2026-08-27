import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../auth_provider.dart';

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _loading = false;
  bool _sent = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    setState(() => _loading = true);
    try {
      await ref
          .read(authProvider.notifier)
          .resetPassword(_emailCtrl.text.trim());
      if (!mounted) return;
      setState(() {
        _sent = true;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed: ${e.toString().replaceAll('Exception: ', '')}',
            style: GoogleFonts.outfit(color: Colors.white),
          ),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Stack(
        children: [
          // ── Gradient Header ───────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: screenSize.height * 0.28,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary,
                    AppColors.primaryLight,
                    AppColors.primaryContainer,
                  ],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_rounded,
                            color: Colors.white),
                        onPressed: () => context.pop(),
                      ),
                      const Spacer(),
                      Text(
                        'Reset Password',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Recover your account credentials',
                        style: GoogleFonts.inter(
                          color: AppColors.grey400,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Form / Success Card ───────────────────────────────────
          Positioned.fill(
            top: screenSize.height * 0.24,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(32)),
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withValues(alpha: 0.12),
                    width: 1,
                  ),
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: _sent
                    ? const _SuccessView()
                    : _FormView(
                        formKey: _formKey,
                        emailCtrl: _emailCtrl,
                        loading: _loading,
                        onSubmit: _submit,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FormView extends StatelessWidget {
  const _FormView({
    required this.formKey,
    required this.emailCtrl,
    required this.loading,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailCtrl;
  final bool loading;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.md),
          const Icon(Icons.lock_reset_rounded,
                  size: 64, color: Color(0xFFF59E0B))
              .animate()
              .scale(duration: 500.ms, curve: Curves.easeOutBack),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Enter your email address and we\'ll send you a link to reset your password.',
            style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14),
            textAlign: TextAlign.center,
          ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
          const SizedBox(height: AppSpacing.xl),
          TextFormField(
            controller: emailCtrl,
            enabled: !loading,
            keyboardType: TextInputType.emailAddress,
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              labelText: 'Email Address',
              labelStyle: GoogleFonts.outfit(color: Colors.white60),
              prefixIcon:
                  const Icon(Icons.email_outlined, color: Colors.white60),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Enter your email';
              if (!v.contains('@')) return 'Enter a valid email';
              return null;
            },
          ).animate().fadeIn(duration: 400.ms, delay: 300.ms),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFF59E0B),
                    Color(0xFFF97316),
                  ],
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color.fromRGBO(245, 158, 11, 0.35),
                    blurRadius: 20,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: loading ? null : onSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'SEND RESET LINK',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          letterSpacing: 1.5,
                        ),
                      ),
              ),
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 400.ms),
        ],
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  const _SuccessView();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.xl),
        Container(
          width: 100,
          height: 100,
          margin: const EdgeInsets.symmetric(horizontal: 80),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF10B981)),
          ),
          child: const Icon(Icons.check_rounded,
              size: 56, color: Color(0xFF10B981)),
        ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
        const SizedBox(height: AppSpacing.xl),
        Text(
          'Check your email!',
          style: GoogleFonts.dmSerifDisplay(
            color: Colors.white,
            fontSize: 26,
          ),
          textAlign: TextAlign.center,
        ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
        const SizedBox(height: AppSpacing.md),
        Text(
          'We\'ve sent a password reset link. Please check your inbox.',
          style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14),
          textAlign: TextAlign.center,
        ).animate().fadeIn(duration: 400.ms, delay: 300.ms),
        const SizedBox(height: AppSpacing.xl),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => context.pop(),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: Color(0xFFF59E0B), width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              'BACK TO LOGIN',
              style: GoogleFonts.outfit(
                color: const Color(0xFFF59E0B),
                fontWeight: FontWeight.bold,
                fontSize: 13,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ).animate().fadeIn(duration: 400.ms, delay: 400.ms),
      ],
    );
  }
}
