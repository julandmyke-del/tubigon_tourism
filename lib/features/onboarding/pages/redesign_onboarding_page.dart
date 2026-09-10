import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/asset_paths.dart';
import '../../../core/services/local_storage_service.dart';
import '../../../core/utils/auth_action_guard.dart';
import '../../authentication/auth_provider.dart';

// ─── Data Models ─────────────────────────────────────────────────────────────

class _FeatureItem {
  final IconData icon;
  final String label;
  const _FeatureItem({required this.icon, required this.label});
}

class _PageDef {
  final int id;
  final String tag;
  final String headline;
  final String sub;
  final String desc;
  final String image;
  final Color accent;
  final List<_FeatureItem>? features;
  final List<_FeatureItem>? categories;

  const _PageDef({
    required this.id,
    required this.tag,
    required this.headline,
    required this.sub,
    required this.desc,
    required this.image,
    required this.accent,
    this.features,
    this.categories,
  });
}

// ─── Page Definitions ────────────────────────────────────────────────────────

const _pages = <_PageDef>[
  _PageDef(
    id: 0,
    tag: 'WELCOME',
    headline: 'Welcome to\nTour Tubigon',
    sub: 'Municipality of Tubigon, Bohol',
    desc:
        'Discover the beauty, culture, and adventures of Tubigon — where pristine beaches, volcanic landmarks, and warm communities await your arrival.',
    image: AssetPaths.onboarding1,
    accent: Color(0xFFF97316),
  ),
  _PageDef(
    id: 1,
    tag: 'EXPLORE',
    headline: 'Explore\nHidden Gems',
    sub: 'Breathtaking Destinations Await',
    desc:
        'From the majestic volcanic plug to serene sandbars — discover stunning tourist attractions, scenic landscapes, and verified destinations across Tubigon.',
    image: AssetPaths.onboarding2,
    accent: Color(0xFF38BDF8),
    features: [
      _FeatureItem(icon: Icons.beach_access_rounded, label: 'Beaches'),
      _FeatureItem(icon: Icons.location_city_rounded, label: 'Landmarks'),
      _FeatureItem(icon: Icons.forest_rounded, label: 'Nature'),
      _FeatureItem(icon: Icons.map_rounded, label: 'Destinations'),
    ],
  ),
  _PageDef(
    id: 2,
    tag: 'PLAN',
    headline: 'Plan Your\nPerfect Journey',
    sub: 'Every Great Trip Starts Here',
    desc:
        'Book reservations, check real-time ferry schedules, explore interactive maps, and craft personalized itineraries — everything you need in one platform.',
    image: AssetPaths.onboarding3,
    accent: Color(0xFFA78BFA),
    features: [
      _FeatureItem(icon: Icons.alt_route_rounded, label: 'Maps'),
      _FeatureItem(icon: Icons.directions_ferry_rounded, label: 'Ferry'),
      _FeatureItem(icon: Icons.calendar_month_rounded, label: 'Bookings'),
      _FeatureItem(icon: Icons.explore_rounded, label: 'Itineraries'),
    ],
  ),
  _PageDef(
    id: 3,
    tag: 'PROTECT',
    headline: 'Protect &\nPreserve Tubigon',
    sub: 'Responsible Tourism for All',
    desc:
        'Help preserve Tubigon\'s natural beauty by following eco-tourism practices, reporting environmental concerns, and supporting sustainable travel.',
    image: AssetPaths.onboarding4,
    accent: Color(0xFF34D399),
    features: [
      _FeatureItem(icon: Icons.eco_rounded, label: 'Eco-Tourism'),
      _FeatureItem(icon: Icons.recycling_rounded, label: 'Sustainable'),
      _FeatureItem(icon: Icons.campaign_rounded, label: 'Report'),
      _FeatureItem(icon: Icons.water_rounded, label: 'Marine Life'),
    ],
  ),
  _PageDef(
    id: 4,
    tag: 'CONNECT',
    headline: 'Support Local\nMSMEs',
    sub: 'Culture, Community & Commerce',
    desc:
        'Explore verified local businesses — artisan galleries, family restaurants, boutique accommodations, and community-led experiences that give back to Tubigon.',
    image: AssetPaths.onboarding5,
    accent: Color(0xFFFBBF24),
    categories: [
      _FeatureItem(icon: Icons.hotel_rounded, label: 'Hotels'),
      _FeatureItem(icon: Icons.restaurant_rounded, label: 'Restaurants'),
      _FeatureItem(icon: Icons.local_cafe_rounded, label: 'Cafes'),
      _FeatureItem(icon: Icons.shopping_bag_rounded, label: 'Crafts'),
      _FeatureItem(icon: Icons.backpack_rounded, label: 'Tours'),
      _FeatureItem(icon: Icons.theater_comedy_rounded, label: 'Attractions'),
    ],
  ),
  _PageDef(
    id: 5,
    tag: 'BEGIN',
    headline: 'Your Adventure\nStarts Now',
    sub: 'Join the Tour Tubigon Community',
    desc:
        'Experience a smarter way to travel with one complete tourism platform built exclusively for Tubigon, Bohol.',
    image: AssetPaths.onboarding6,
    accent: Color(0xFFF97316),
  ),
];

// ─── Main Widget ──────────────────────────────────────────────────────────────

class RedesignOnboardingPage extends ConsumerStatefulWidget {
  final int initialPage;
  final bool showLoginForm;
  final String? returnTo;

  const RedesignOnboardingPage({
    super.key,
    this.initialPage = 0,
    this.showLoginForm = false,
    this.returnTo,
  });

  @override
  ConsumerState<RedesignOnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<RedesignOnboardingPage>
    with TickerProviderStateMixin {
  late final PageController _pageController;
  final FocusNode _focusNode = FocusNode();
  int _currentPage = 0;
  bool _isNavigating = false;
  bool _showLoginForm = false;

  // Form controllers & auth state
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  // Animation controllers for accent color transitions
  late AnimationController _accentController;
  late ColorTween _accentTween;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    _showLoginForm = widget.showLoginForm;
    _pageController = PageController(initialPage: widget.initialPage);
    _accentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    final initialAccent = widget.initialPage < _pages.length
        ? _pages[widget.initialPage].accent
        : _pages[0].accent;
    _accentTween = ColorTween(begin: initialAccent, end: initialAccent);

    // Precache all images
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final p in _pages) {
        precacheImage(AssetImage(p.image), context);
      }
    });
  }

  @override
  void didUpdateWidget(covariant RedesignOnboardingPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialPage != widget.initialPage ||
        oldWidget.showLoginForm != widget.showLoginForm) {
      setState(() {
        _currentPage = widget.initialPage;
        _showLoginForm = widget.showLoginForm;
      });
      if (_pageController.hasClients) {
        _pageController.jumpToPage(widget.initialPage);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _focusNode.dispose();
    _accentController.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _goToPage(int index) {
    if (index < 0 || index >= _pages.length) return;
    final current = _pages[_currentPage];
    final next = _pages[index];
    _accentTween = ColorTween(begin: current.accent, end: next.accent);
    _accentController.forward(from: 0);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 550),
      curve: Curves.easeInOutCubic,
    );
  }

  void _markOnboarded() {
    LocalStorageService.instance.setBool('has_onboarded', value: true);
  }

  void _toggleLoginForm(bool show) {
    setState(() {
      _showLoginForm = show;
      _errorMessage = null;
    });
  }

  void _handleLogin() {
    _toggleLoginForm(true);
  }

  void _handleRegister() {
    _markOnboarded();
    context.go('/auth/login/register');
  }

  Future<void> _submitLogin() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      _markOnboarded();
      await ref.read(authProvider.notifier).signIn(
            email: _emailCtrl.text.trim(),
            password: _passwordCtrl.text,
          );
      if (!mounted) return;
      final auth = ref.read(authProvider);
      context.go(safeTouristReturnRoute(widget.returnTo) ?? auth.homeRoute);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleExploreAsGuest() async {
    if (_isNavigating) return;
    setState(() => _isNavigating = true);
    _markOnboarded();
    try {
      await ref.read(authProvider.notifier).continueAsGuest();
    } catch (_) {
      if (mounted) context.go('/home');
    } finally {
      if (mounted) setState(() => _isNavigating = false);
    }
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
          event.logicalKey == LogicalKeyboardKey.arrowDown) {
        _goToPage(_currentPage + 1);
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
          event.logicalKey == LogicalKeyboardKey.arrowUp) {
        _goToPage(_currentPage - 1);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_currentPage];
    final isLast = _currentPage == _pages.length - 1;
    final size = MediaQuery.of(context).size;

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: const Color(0xFF06101E),
        body: GestureDetector(
          onHorizontalDragEnd: (details) {
            if (details.primaryVelocity == null) return;
            if (details.primaryVelocity! < -300) {
              _goToPage(_currentPage + 1);
            } else if (details.primaryVelocity! > 300) {
              _goToPage(_currentPage - 1);
            }
          },
          child: Stack(
            children: [
              // ── Full-screen hero PageView ────────────────────────────────
              PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (context, index) {
                  final item = _pages[index];
                  return _HeroImage(image: item.image, accent: item.accent);
                },
              ),

              // ── Accent ambient glow (top) ────────────────────────────────
              AnimatedBuilder(
                animation: _accentController,
                builder: (context, child) {
                  final color =
                      _accentTween.evaluate(_accentController) ?? page.accent;
                  return Positioned(
                    top: -80,
                    left: size.width / 2 - 200,
                    child: Container(
                      width: 400,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            color.withValues(alpha: 0.18),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.7],
                        ),
                      ),
                    ),
                  );
                },
              ),

              // ── Floating side orbs ───────────────────────────────────────
              _FloatingOrb(
                accent: page.accent,
                top: size.height * 0.08,
                right: size.width * 0.04,
                size: 120,
                opacity: 0.12,
              ),

              // ── Top bar ─────────────────────────────────────────────────
              SafeArea(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Brand logo
                      Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 500),
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: LinearGradient(
                                colors: [
                                  page.accent,
                                  page.accent.withValues(alpha: 0.7)
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: page.accent.withValues(alpha: 0.4),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                'T',
                                style: GoogleFonts.dmSerifDisplay(
                                  fontSize: 18,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'TUBIGON',
                                style: GoogleFonts.dmSerifDisplay(
                                  fontSize: 17,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Text(
                                'SMART TOURISM',
                                style: GoogleFonts.outfit(
                                  fontSize: 8,
                                  color: Colors.white.withValues(alpha: 0.5),
                                  letterSpacing: 2.0,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // Page counter + Skip
                      Row(
                        children: [
                          Text(
                            '${(_currentPage + 1).toString().padLeft(2, '0')} / ${_pages.length.toString().padLeft(2, '0')}',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.4),
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.5,
                            ),
                          ),
                          if (!isLast) ...[
                            const SizedBox(width: 12),
                            GestureDetector(
                              onTap: () => _goToPage(_pages.length - 1),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.18)),
                                ),
                                child: Text(
                                  'Skip →',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // ── Centered Glass Panel ─────────────────────────────────────
              Positioned.fill(
                child: SafeArea(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 24),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 720),
                        child: _BottomPanel(
                          page: page,
                          isLast: isLast,
                          currentPage: _currentPage,
                          totalPages: _pages.length,
                          isNavigating: _isNavigating,
                          onGoToPage: _goToPage,
                          onLogin: _handleLogin,
                          onRegister: _handleRegister,
                          onGuest: _handleExploreAsGuest,
                          showLoginForm: _showLoginForm,
                          formKey: _formKey,
                          emailCtrl: _emailCtrl,
                          passwordCtrl: _passwordCtrl,
                          obscurePassword: _obscurePassword,
                          onToggleObscure: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                          isLoading: _isLoading,
                          errorMessage: _errorMessage,
                          onSubmitLogin: _submitLogin,
                          onBackToButtons: () => _toggleLoginForm(false),
                        ),
                      ),
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

// ─── Hero Image with Ken Burns ────────────────────────────────────────────────

class _HeroImage extends StatefulWidget {
  final String image;
  final Color accent;
  const _HeroImage({required this.image, required this.accent});

  @override
  State<_HeroImage> createState() => _HeroImageState();
}

class _HeroImageState extends State<_HeroImage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 12));
    _scale = Tween(begin: 1.0, end: 1.12)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Hero image with Ken Burns zoom
        AnimatedBuilder(
          animation: _scale,
          builder: (context, child) => Transform.scale(
            scale: _scale.value,
            child: child,
          ),
          child: Image.asset(
            widget.image,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, __, ___) => Container(
              color: const Color(0xFF0D1E38),
              child: const Center(
                child:
                    Icon(Icons.image_outlined, color: Colors.white24, size: 64),
              ),
            ),
          ),
        ),

        // Multi-layer cinematic gradient overlay
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x47061018),
                Colors.transparent,
                Color(0xCC06101E),
                Color(0xF506101E),
              ],
              stops: [0.0, 0.35, 0.72, 1.0],
            ),
          ),
        ),
        // Side vignette
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                const Color(0xFF06101E).withValues(alpha: 0.3),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Floating Orb ─────────────────────────────────────────────────────────────

class _FloatingOrb extends StatefulWidget {
  final Color accent;
  final double? top;
  final double? right;
  final double size;
  final double opacity;

  const _FloatingOrb({
    required this.accent,
    this.top,
    this.right,
    required this.size,
    required this.opacity,
  });

  @override
  State<_FloatingOrb> createState() => _FloatingOrbState();
}

class _FloatingOrbState extends State<_FloatingOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 8));
    _anim = Tween(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _ctrl.repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: widget.top,
      right: widget.right,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, -20 * _anim.value),
          child: child,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 700),
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.accent.withValues(alpha: widget.opacity),
          ),
          child: ClipOval(
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    widget.accent.withValues(alpha: widget.opacity),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Bottom Panel ─────────────────────────────────────────────────────────────

class _BottomPanel extends StatelessWidget {
  final _PageDef page;
  final bool isLast;
  final int currentPage;
  final int totalPages;
  final bool isNavigating;
  final void Function(int) onGoToPage;
  final VoidCallback onLogin;
  final VoidCallback onRegister;
  final Future<void> Function() onGuest;
  // Login form state
  final bool showLoginForm;
  final GlobalKey<FormState> formKey;
  final TextEditingController emailCtrl;
  final TextEditingController passwordCtrl;
  final bool obscurePassword;
  final VoidCallback onToggleObscure;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onSubmitLogin;
  final VoidCallback onBackToButtons;

  const _BottomPanel({
    required this.page,
    required this.isLast,
    required this.currentPage,
    required this.totalPages,
    required this.isNavigating,
    required this.onGoToPage,
    required this.onLogin,
    required this.onRegister,
    required this.onGuest,
    required this.showLoginForm,
    required this.formKey,
    required this.emailCtrl,
    required this.passwordCtrl,
    required this.obscurePassword,
    required this.onToggleObscure,
    required this.isLoading,
    required this.errorMessage,
    required this.onSubmitLogin,
    required this.onBackToButtons,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: EdgeInsets.zero,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          // Semi-transparent glass effect
          color: const Color(0xFF06101E).withValues(alpha: 0.88),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.55),
              blurRadius: 40,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Shimmer accent line at top
              Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  margin: const EdgeInsets.only(top: 12, bottom: 0),
                  width: 56,
                  height: 3,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        page.accent.withValues(alpha: 0.9),
                        Colors.transparent,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Scrollable content area
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.65,
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
                  child: _PageContent(
                    page: page,
                    isLast: isLast,
                    onLogin: onLogin,
                    onRegister: onRegister,
                    onGuest: onGuest,
                    isNavigating: isNavigating,
                    currentPage: currentPage,
                    showLoginForm: showLoginForm,
                    formKey: formKey,
                    emailCtrl: emailCtrl,
                    passwordCtrl: passwordCtrl,
                    obscurePassword: obscurePassword,
                    onToggleObscure: onToggleObscure,
                    isLoading: isLoading,
                    errorMessage: errorMessage,
                    onSubmitLogin: onSubmitLogin,
                    onBackToButtons: onBackToButtons,
                  ),
                ),
              ),

              // Fixed bottom navigation
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 14, 28, 20),
                child: _BottomNav(
                  page: page,
                  currentPage: currentPage,
                  totalPages: totalPages,
                  isLast: isLast,
                  onGoToPage: onGoToPage,
                  onLogin: onLogin,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Page Content ─────────────────────────────────────────────────────────────

class _PageContent extends StatelessWidget {
  final _PageDef page;
  final bool isLast;
  final int currentPage;
  final bool isNavigating;
  final VoidCallback onLogin;
  final VoidCallback onRegister;
  final Future<void> Function() onGuest;
  // Login form state
  final bool showLoginForm;
  final GlobalKey<FormState> formKey;
  final TextEditingController emailCtrl;
  final TextEditingController passwordCtrl;
  final bool obscurePassword;
  final VoidCallback onToggleObscure;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onSubmitLogin;
  final VoidCallback onBackToButtons;

  const _PageContent({
    required this.page,
    required this.isLast,
    required this.currentPage,
    required this.isNavigating,
    required this.onLogin,
    required this.onRegister,
    required this.onGuest,
    required this.showLoginForm,
    required this.formKey,
    required this.emailCtrl,
    required this.passwordCtrl,
    required this.obscurePassword,
    required this.onToggleObscure,
    required this.isLoading,
    required this.errorMessage,
    required this.onSubmitLogin,
    required this.onBackToButtons,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ── Tag pill ──────────────────────────────────────────────────────
        AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          decoration: BoxDecoration(
            color: page.accent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: page.accent.withValues(alpha: 0.45)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: page.accent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: page.accent, blurRadius: 6),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                page.tag,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: page.accent,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.2,
                ),
              ),
            ],
          ),
        )
            .animate(key: ValueKey('tag_$currentPage'))
            .fadeIn(duration: 350.ms, delay: 60.ms)
            .scale(begin: const Offset(0.85, 0.85), end: const Offset(1, 1)),
        const SizedBox(height: 14),

        // ── Headline ──────────────────────────────────────────────────────
        Text(
          page.headline,
          textAlign: TextAlign.center,
          style: GoogleFonts.dmSerifDisplay(
            fontSize: 34,
            height: 1.15,
            color: Colors.white,
            shadows: const [
              Shadow(
                color: Color(0x4006101E),
                blurRadius: 18,
                offset: Offset(0, 2),
              ),
            ],
          ),
        )
            .animate(key: ValueKey('head_$currentPage'))
            .fadeIn(duration: 400.ms)
            .slideY(begin: 0.12, end: 0, curve: Curves.easeOut),
        const SizedBox(height: 6),

        // ── Sub headline ──────────────────────────────────────────────────
        Text(
          page.sub,
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontSize: 13,
            color: Colors.white.withValues(alpha: 0.55),
            fontWeight: FontWeight.w600,
            letterSpacing: 2.2,
          ),
        )
            .animate(key: ValueKey('sub_$currentPage'))
            .fadeIn(duration: 400.ms, delay: 50.ms),
        const SizedBox(height: 14),

        // ── Description ───────────────────────────────────────────────────
        Text(
          page.desc,
          textAlign: TextAlign.justify,
          style: GoogleFonts.outfit(
            fontSize: 16,
            color: Colors.white.withValues(alpha: 0.85),
            height: 1.6,
          ),
        )
            .animate(key: ValueKey('desc_$currentPage'))
            .fadeIn(duration: 450.ms, delay: 80.ms),
        const SizedBox(height: 18),

        // ── Feature grid (4 items) ────────────────────────────────────────
        if (page.features != null) ...[
          Row(
            children: List.generate(page.features!.length, (i) {
              final f = page.features![i];
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(
                    left: i == 0 ? 0 : 5,
                    right: i == page.features!.length - 1 ? 0 : 5,
                  ),
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: page.accent.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(f.icon, size: 20, color: page.accent),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        f.label,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                )
                    .animate(key: ValueKey('feat_${currentPage}_$i'))
                    .fadeIn(
                        duration: 380.ms,
                        delay: Duration(milliseconds: 120 + i * 60))
                    .slideY(begin: 0.15, end: 0),
              );
            }),
          ),
          const SizedBox(height: 16),
        ],

        // ── Category grid (6 items in 2 rows of 3) ───────────────────────
        if (page.categories != null) ...[
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: List.generate(page.categories!.length, (i) {
              final c = page.categories![i];
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.16)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(c.icon, size: 16, color: page.accent),
                    const SizedBox(width: 8),
                    Text(
                      c.label,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )
                  .animate(key: ValueKey('cat_${currentPage}_$i'))
                  .fadeIn(
                      duration: 360.ms,
                      delay: Duration(milliseconds: 100 + i * 55))
                  .scale(
                      begin: const Offset(0.88, 0.88), end: const Offset(1, 1));
            }),
          ),
          const SizedBox(height: 16),
        ],

        // ── Final slide: Login form OR CTA buttons ──────────────────────────
        if (isLast && showLoginForm) ...[
          // ── Inline Login Form ────────────────────────────────────────────
          Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Back arrow
                Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: onBackToButtons,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.arrow_back_ios_rounded,
                            size: 14, color: page.accent),
                        const SizedBox(width: 4),
                        Text(
                          'Back',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: page.accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Welcome text
                Text(
                  'Welcome Back',
                  style: GoogleFonts.dmSerifDisplay(
                    fontSize: 26,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Sign in to continue your journey',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(height: 20),

                // Error message
                if (errorMessage != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color:
                              const Color(0xFFEF4444).withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            size: 18, color: Color(0xFFEF4444)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            errorMessage!,
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              color: const Color(0xFFFCA5A5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 300.ms)
                      .shake(hz: 2, offset: const Offset(4, 0)),

                // Email field
                TextFormField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 15),
                  decoration: InputDecoration(
                    labelText: 'Email',
                    labelStyle: GoogleFonts.outfit(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 14,
                    ),
                    prefixIcon: Icon(Icons.email_outlined,
                        color: page.accent.withValues(alpha: 0.7), size: 20),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.07),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: page.accent, width: 1.5),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFEF4444)),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                          color: Color(0xFFEF4444), width: 1.5),
                    ),
                    errorStyle: GoogleFonts.outfit(
                        fontSize: 11, color: const Color(0xFFFCA5A5)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!v.contains('@')) return 'Please enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Password field
                TextFormField(
                  controller: passwordCtrl,
                  obscureText: obscurePassword,
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 15),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    labelStyle: GoogleFonts.outfit(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 14,
                    ),
                    prefixIcon: Icon(Icons.lock_outline_rounded,
                        color: page.accent.withValues(alpha: 0.7), size: 20),
                    suffixIcon: GestureDetector(
                      onTap: onToggleObscure,
                      child: Icon(
                        obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: Colors.white.withValues(alpha: 0.4),
                        size: 20,
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.07),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: page.accent, width: 1.5),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFEF4444)),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                          color: Color(0xFFEF4444), width: 1.5),
                    ),
                    errorStyle: GoogleFonts.outfit(
                        fontSize: 11, color: const Color(0xFFFCA5A5)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Please enter your password';
                    }
                    if (v.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => onSubmitLogin(),
                ),
                const SizedBox(height: 8),

                // Forgot password link
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () => context.go('/auth/login/forgot-password'),
                    child: Text(
                      'Forgot Password?',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: page.accent.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Login button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : onSubmitLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF97316),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          const Color(0xFFF97316).withValues(alpha: 0.5),
                      elevation: 6,
                      shadowColor:
                          const Color(0xFFF97316).withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            'SIGN IN',
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.4,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 12),

                // Create account link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                    GestureDetector(
                      onTap: onRegister,
                      child: Text(
                        'Register',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: page.accent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Explore as guest
                GestureDetector(
                  onTap: isNavigating ? null : () => onGuest(),
                  child: Text(
                    'or explore as guest →',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.4),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.08, end: 0),
        ] else if (isLast) ...[
          // ── Original CTA Buttons (before login form is shown) ───────────
          // Get Started button
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: onLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF97316),
                foregroundColor: Colors.white,
                elevation: 8,
                shadowColor: const Color(0xFFF97316).withValues(alpha: 0.45),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'GET STARTED',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, size: 20),
                ],
              ),
            ),
          )
              .animate()
              .fadeIn(duration: 400.ms, delay: 80.ms)
              .slideY(begin: 0.1, end: 0),
          const SizedBox(height: 10),

          // Create Account button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton(
              onPressed: onRegister,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFFDBA74),
                side: BorderSide(
                    color: const Color(0xFFF97316).withValues(alpha: 0.65),
                    width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'CREATE ACCOUNT',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.4,
                ),
              ),
            ),
          )
              .animate()
              .fadeIn(duration: 400.ms, delay: 150.ms)
              .slideY(begin: 0.1, end: 0),
          const SizedBox(height: 10),

          // Guest mode button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: TextButton(
              onPressed: isNavigating ? null : () => onGuest(),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white.withValues(alpha: 0.70),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
                ),
              ),
              child: isNavigating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Text(
                      'EXPLORE AS GUEST →',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.0,
                      ),
                    ),
            ),
          )
              .animate()
              .fadeIn(duration: 400.ms, delay: 220.ms)
              .slideY(begin: 0.1, end: 0),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

// ─── Bottom Navigation Bar ────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  final _PageDef page;
  final int currentPage;
  final int totalPages;
  final bool isLast;
  final void Function(int) onGoToPage;
  final VoidCallback onLogin;

  const _BottomNav({
    required this.page,
    required this.currentPage,
    required this.totalPages,
    required this.isLast,
    required this.onGoToPage,
    required this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // ── Dot indicators ─────────────────────────────────────────────────
        Row(
          children: List.generate(totalPages, (i) {
            final active = i == currentPage;
            return GestureDetector(
              onTap: () => onGoToPage(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeInOut,
                margin: const EdgeInsets.only(right: 7),
                width: active ? 28 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: active
                      ? page.accent
                      : Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: page.accent.withValues(alpha: 0.55),
                            blurRadius: 10,
                          )
                        ]
                      : null,
                ),
              ),
            );
          }),
        ),

        // ── Prev / Next navigation ──────────────────────────────────────────
        Row(
          children: [
            // Back button (shown from page 1 onward)
            if (currentPage > 0) ...[
              _NavButton(
                onTap: () => onGoToPage(currentPage - 1),
                accent: page.accent,
                isNext: false,
              ),
              const SizedBox(width: 10),
            ],

            // Next / Login button (always visible)
            if (!isLast)
              _NextButton(
                accent: page.accent,
                label: 'Next',
                onTap: () => onGoToPage(currentPage + 1),
              )
            else
              _NextButton(
                accent: page.accent,
                label: 'Login',
                onTap: onLogin,
              ),
          ],
        ),
      ],
    );
  }
}

// ─── Nav Pill Button ──────────────────────────────────────────────────────────

class _NextButton extends StatelessWidget {
  final Color accent;
  final String label;
  final VoidCallback onTap;

  const _NextButton({
    required this.accent,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: accent,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.45),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_rounded,
                color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final VoidCallback onTap;
  final Color accent;
  final bool isNext;

  const _NavButton({
    required this.onTap,
    required this.accent,
    required this.isNext,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
        ),
        child: Icon(
          isNext ? Icons.arrow_forward_rounded : Icons.arrow_back_rounded,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }
}
