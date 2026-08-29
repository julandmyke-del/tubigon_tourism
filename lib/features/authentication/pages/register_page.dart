import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../auth_provider.dart';
import '../google_auth_service.dart';
import '../widgets/google_web_button.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  bool _agreed = false;
  bool _showGmailForm = false;
  String? _googleConfigurationError;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _googleEvents;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) _initializeGoogleForWeb();
  }

  Future<void> _initializeGoogleForWeb() async {
    try {
      await GoogleAuthService.initialize();
      _googleEvents = GoogleAuthService.authenticationEvents.listen((event) {
        if (event is GoogleSignInAuthenticationEventSignIn) {
          _completeGoogleSignUp(event.user);
        }
      });
    } catch (error) {
      if (mounted) {
        setState(() => _googleConfigurationError =
            error.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  @override
  void dispose() {
    _googleEvents?.cancel();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    if (!_agreed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please agree to the terms to continue',
            style: GoogleFonts.outfit(color: Colors.white),
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final result = await ref.read(authProvider.notifier).signUp(
            name: _nameCtrl.text.trim(),
            email: _emailCtrl.text.trim(),
            password: _passwordCtrl.text,
            passwordConfirmation: _confirmCtrl.text,
          );
      if (!mounted) return;
      final email = (result['email'] ?? _emailCtrl.text.trim()).toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['email_sent'] == true
                ? 'Account created. Enter the code sent to your email.'
                : 'Account created. Use Resend Email if the message did not arrive.',
            style: GoogleFonts.outfit(color: Colors.white),
          ),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 3),
        ),
      );
      context
          .go('/auth/login/verify-email?email=${Uri.encodeComponent(email)}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Registration failed: ${e.toString().replaceAll('Exception: ', '')}',
            style: GoogleFonts.outfit(color: Colors.white),
          ),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _googleSignUp() async {
    setState(() => _loading = true);
    try {
      await ref.read(authProvider.notifier).googleSignIn();
      if (!mounted) return;
      context.go(ref.read(authProvider).homeRoute);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error.toString().replaceAll('Exception: ', '')),
        backgroundColor: AppColors.error,
      ));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _completeGoogleSignUp(GoogleSignInAccount account) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await ref.read(authProvider.notifier).completeGoogleSignIn(account);
      if (mounted) context.go(ref.read(authProvider).homeRoute);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  static final RegExp _emailRegex = RegExp(r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$");

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
                        'Create Account',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Join the Tubigon Smart Tourism community',
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

          // ── Form Card ─────────────────────────────────────────────
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
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: AppSpacing.sm),

                      Text(
                        'Choose how you want to register',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      if (kIsWeb)
                        if (_googleConfigurationError != null)
                          Text(
                            _googleConfigurationError!,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                                color: AppColors.error, fontSize: 12),
                          )
                        else if (_loading)
                          const Center(
                              child: CircularProgressIndicator(
                                  color: Colors.white))
                        else
                          Center(child: buildGoogleWebButton())
                      else
                        OutlinedButton.icon(
                          onPressed: _loading ? null : _googleSignUp,
                          style: OutlinedButton.styleFrom(
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.08),
                            side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.2)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                          icon: const Icon(Icons.g_mobiledata_rounded,
                              color: Color(0xFFEA4335), size: 26),
                          label: Text(
                            'Continue with Google',
                            style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                        ),

                      Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: AppSpacing.md),
                        child: Row(
                          children: [
                            const Expanded(
                                child: Divider(color: Colors.white24)),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: Text('OR',
                                  style: GoogleFonts.outfit(
                                      color: Colors.white54)),
                            ),
                            const Expanded(
                                child: Divider(color: Colors.white24)),
                          ],
                        ),
                      ),

                      OutlinedButton.icon(
                        onPressed: _loading
                            ? null
                            : () => setState(
                                () => _showGmailForm = !_showGmailForm),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFFF97316)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: const Icon(Icons.mail_outline_rounded),
                        label: Text(
                          _showGmailForm
                              ? 'Hide Email Registration'
                              : 'Register with Email',
                          style:
                              GoogleFonts.outfit(fontWeight: FontWeight.bold),
                        ),
                      ),

                      if (_showGmailForm) ...[
                        const SizedBox(height: AppSpacing.lg),

                        // Account Role Indicator (Fixed as Tourist / User)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF38BDF8)
                                  .withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF38BDF8)
                                      .withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.tour_rounded,
                                  color: Color(0xFF38BDF8),
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Account Role',
                                      style: GoogleFonts.inter(
                                        color: Colors.white54,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Tourist / General User',
                                      style: GoogleFonts.outfit(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981)
                                      .withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: const Color(0xFF10B981),
                                      width: 0.8),
                                ),
                                child: Text(
                                  'Default',
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF34D399),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ).animate().fadeIn(duration: 400.ms, delay: 150.ms),

                        const SizedBox(height: AppSpacing.md),

                        // Full Name Input
                        TextFormField(
                          controller: _nameCtrl,
                          enabled: !_loading,
                          style: GoogleFonts.outfit(
                              color: Colors.white, fontSize: 14),
                          decoration: InputDecoration(
                            labelText: 'Full Name',
                            labelStyle:
                                GoogleFonts.outfit(color: Colors.white60),
                            prefixIcon: const Icon(Icons.person_outline_rounded,
                                color: Colors.white60),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Enter your name'
                              : null,
                        ).animate().fadeIn(duration: 400.ms, delay: 200.ms),

                        const SizedBox(height: AppSpacing.md),

                        // Email Input
                        TextFormField(
                          controller: _emailCtrl,
                          enabled: !_loading,
                          keyboardType: TextInputType.emailAddress,
                          style: GoogleFonts.outfit(
                              color: Colors.white, fontSize: 14),
                          decoration: InputDecoration(
                            labelText: 'Email Address',
                            labelStyle:
                                GoogleFonts.outfit(color: Colors.white60),
                            prefixIcon: const Icon(Icons.email_outlined,
                                color: Colors.white60),
                          ),
                          validator: (v) {
                            final trimmed = v?.trim() ?? '';
                            if (trimmed.isEmpty) return 'Enter your email';
                            if (trimmed.length > 254) {
                              return 'Email is too long';
                            }
                            if (!_emailRegex.hasMatch(trimmed)) {
                              return 'Enter a valid email address';
                            }
                            return null;
                          },
                        ).animate().fadeIn(duration: 400.ms, delay: 300.ms),

                        const SizedBox(height: AppSpacing.md),

                        // Password Input
                        TextFormField(
                          controller: _passwordCtrl,
                          enabled: !_loading,
                          obscureText: _obscurePass,
                          style: GoogleFonts.outfit(
                              color: Colors.white, fontSize: 14),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            labelStyle:
                                GoogleFonts.outfit(color: Colors.white60),
                            prefixIcon: const Icon(Icons.lock_outline_rounded,
                                color: Colors.white60),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePass
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: Colors.white60,
                              ),
                              onPressed: () =>
                                  setState(() => _obscurePass = !_obscurePass),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'Enter a password';
                            }
                            if (v.length < 8) return 'At least 8 characters';
                            return null;
                          },
                        ).animate().fadeIn(duration: 400.ms, delay: 400.ms),

                        const SizedBox(height: AppSpacing.md),

                        // Confirm Password Input
                        TextFormField(
                          controller: _confirmCtrl,
                          enabled: !_loading,
                          obscureText: _obscureConfirm,
                          style: GoogleFonts.outfit(
                              color: Colors.white, fontSize: 14),
                          decoration: InputDecoration(
                            labelText: 'Confirm Password',
                            labelStyle:
                                GoogleFonts.outfit(color: Colors.white60),
                            prefixIcon: const Icon(Icons.lock_outline_rounded,
                                color: Colors.white60),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirm
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: Colors.white60,
                              ),
                              onPressed: () => setState(
                                  () => _obscureConfirm = !_obscureConfirm),
                            ),
                          ),
                          validator: (v) {
                            if (v != _passwordCtrl.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ).animate().fadeIn(duration: 400.ms, delay: 500.ms),

                        const SizedBox(height: AppSpacing.sm),

                        // Terms Checkbox
                        CheckboxListTile(
                          value: _agreed,
                          onChanged: (v) =>
                              setState(() => _agreed = v ?? false),
                          title: Text.rich(
                            TextSpan(
                              text: 'I agree to the ',
                              style: GoogleFonts.outfit(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                              children: [
                                TextSpan(
                                  text: 'Terms & Conditions',
                                  style: GoogleFonts.outfit(
                                    color: const Color(0xFF4DA8DA),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const TextSpan(text: ' and '),
                                TextSpan(
                                  text: 'Privacy Policy',
                                  style: GoogleFonts.outfit(
                                    color: const Color(0xFF4DA8DA),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          activeColor: AppColors.accent,
                        ).animate().fadeIn(duration: 400.ms, delay: 600.ms),

                        const SizedBox(height: AppSpacing.md),

                        // Register Button
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
                              onPressed: _loading ? null : _register,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: _loading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      'CREATE ACCOUNT',
                                      style: GoogleFonts.outfit(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                            ),
                          ),
                        ).animate().fadeIn(duration: 400.ms, delay: 700.ms),
                      ],

                      const SizedBox(height: AppSpacing.lg),

                      // Sign In Redirect
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Already have an account?',
                            style: GoogleFonts.outfit(
                              color: Colors.white60,
                              fontSize: 13,
                            ),
                          ),
                          TextButton(
                            onPressed: () => context.pop(),
                            child: Text(
                              'Sign In',
                              style: GoogleFonts.outfit(
                                color: AppColors.accent,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ).animate().fadeIn(duration: 400.ms, delay: 800.ms),
                    ],
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
