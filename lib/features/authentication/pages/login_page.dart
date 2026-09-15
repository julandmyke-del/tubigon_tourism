import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/services/local_storage_service.dart';
import '../../../core/routes/route_names.dart';
import '../../../core/widgets/app_logo.dart';
import '../auth_provider.dart';
import '../google_auth_service.dart';
import '../widgets/google_web_button.dart';

class _IntroPageDef {
  final int id;
  final String tag;
  final String headline;
  final String sub;
  final String desc;
  final String image;
  final String alt;
  final Color accent;
  final List<Map<String, String>>? features;
  final List<Map<String, String>>? categories;
  final List<Map<String, String>>? smartFeatures;

  const _IntroPageDef({
    required this.id,
    required this.tag,
    required this.headline,
    required this.sub,
    required this.desc,
    required this.image,
    required this.alt,
    required this.accent,
    this.features,
    this.categories,
    this.smartFeatures,
  });
}

const _introPages = <_IntroPageDef>[
  _IntroPageDef(
    id: 0,
    tag: 'DISCOVER',
    headline: 'Discover\nHidden Paradise',
    sub: 'Explore Beyond the Horizon',
    desc:
        "Breathtaking beaches, misty mountains, cascading waterfalls — nature's most spectacular destinations await your discovery.",
    image:
        'https://images.unsplash.com/photo-1594485770512-f206820b7cc1?w=1600&h=1000&fit=crop&auto=format',
    alt: 'Silhouette of people on a beach during a golden sunset',
    accent: Color(0xFFF59E0B),
    features: [
      {
        'icon': '🏝️',
        'label': 'White Sand Beaches',
        'desc':
            'Explore pristine tropical shores and crystal-clear waters in Tubigon.'
      },
      {
        'icon': '⛰️',
        'label': 'Scenic Hills',
        'desc':
            'Panoramic viewpoints overlooking lush islands and ocean horizons.'
      },
      {
        'icon': '🌊',
        'label': 'Marine Sanctuaries',
        'desc':
            'Protected reefs bustling with colorful sea life and coral gardens.'
      },
      {
        'icon': '🏛️',
        'label': 'Heritage Sites',
        'desc':
            'Rich cultural history, historic landmarks, and ancestral traditions.'
      },
    ],
  ),
  _IntroPageDef(
    id: 1,
    tag: 'PLAN',
    headline: 'Plan Your\nPerfect Journey',
    sub: 'Every Great Trip Starts Here',
    desc:
        'Interactive maps, curated travel guides, and seamless reservations — everything you need to craft your ideal adventure.',
    image:
        'https://images.unsplash.com/photo-1771784969512-15614b5f3286?w=1600&h=1000&fit=crop&auto=format',
    alt:
        'Person in hoodie overlooking a vast sea of clouds from a mountain peak',
    accent: Color(0xFF38BDF8),
    features: [
      {
        'icon': '🗺️',
        'label': 'Interactive Maps',
        'desc': 'GPS navigation and pinpoints for tourist spots across Tubigon.'
      },
      {
        'icon': '📖',
        'label': 'Travel Guides',
        'desc': 'Insider itineraries and local tips for memorable experiences.'
      },
      {
        'icon': '📅',
        'label': 'Easy Reservations',
        'desc': 'Book hotels, boat tours, and restaurant seats in seconds.'
      },
      {
        'icon': '⭐',
        'label': 'Curated Lists',
        'desc': 'Top-rated spots rated by fellow travelers and verified locals.'
      },
    ],
  ),
  _IntroPageDef(
    id: 2,
    tag: 'CONNECT',
    headline: 'Support Local\nTourism',
    sub: 'Culture, Community & Connection',
    desc:
        'Authentic local experiences — family restaurants, hidden cafes, boutique resorts, and community-led tours that give back.',
    image:
        'https://images.unsplash.com/photo-1584208632661-f8db31bb6489?w=1600&h=1000&fit=crop&auto=format',
    alt: 'Vibrant local market with people shopping during daytime',
    accent: Color(0xFF10B981),
    categories: [
      {
        'icon': '🏨',
        'label': 'Hotels & Resorts',
        'desc': 'Stay at beachfront resorts, cozy inns, and homestays.'
      },
      {
        'icon': '🍽️',
        'label': 'Restaurants',
        'desc': 'Savor fresh seafood and authentic Boholano culinary delights.'
      },
      {
        'icon': '☕',
        'label': 'Cafes',
        'desc':
            'Relax at seaside cafes with artisanal coffee and local pastries.'
      },
      {
        'icon': '🎭',
        'label': 'Attractions',
        'desc': 'Discover island hopping, weaving centers, and cultural shows.'
      },
      {
        'icon': '🎒',
        'label': 'Tour Operators',
        'desc': 'Guided excursions led by accredited local tour guides.'
      },
      {
        'icon': '🛍️',
        'label': 'Souvenirs',
        'desc':
            'Support MSMEs crafting woven crafts and famous local delicacies.'
      },
    ],
  ),
  _IntroPageDef(
    id: 3,
    tag: 'SMART',
    headline: 'Travel\nSmarter',
    sub: 'Your Intelligent Travel Companion',
    desc:
        'Real-time ferry schedules, weather alerts, emergency contacts, and offline guides — all within reach wherever you roam.',
    image:
        'https://images.unsplash.com/photo-1564460549828-f0219a31bf90?w=1600&h=1000&fit=crop&auto=format',
    alt: 'Waterfalls cascading beside lush tropical trees',
    accent: Color(0xFF8B5CF6),
    smartFeatures: [
      {
        'icon': '📴',
        'label': 'Offline Guide',
        'desc':
            'Access maps and essential information even without cell service.'
      },
      {
        'icon': '🚨',
        'label': 'Emergency',
        'desc':
            'One-tap access to local police, medical, and coast guard helplines.'
      },
      {
        'icon': '🎪',
        'label': 'Events',
        'desc':
            'Stay updated on local festivals, night markets, and town celebrations.'
      },
      {
        'icon': '⛴️',
        'label': 'Ferry Schedules',
        'desc': 'Live departure times for Cebu-Tubigon sea transport routes.'
      },
      {
        'icon': '🌿',
        'label': 'Eco Tourism',
        'desc': 'Promote sustainable travel and environmental protection tips.'
      },
      {
        'icon': '🌤️',
        'label': 'Weather',
        'desc': 'Real-time weather forecasts and marine sea condition updates.'
      },
      {
        'icon': '📢',
        'label': 'Announcements',
        'desc': 'Official advisory alerts from LGU Tubigon Tourism Office.'
      },
      {
        'icon': '🧭',
        'label': 'Navigation',
        'desc': 'Step-by-step turn guidance to your favorite destinations.'
      },
    ],
  ),
  _IntroPageDef(
    id: 4,
    tag: 'BEGIN',
    headline: 'Your Adventure\nStarts Here',
    sub: 'Sign In to Continue Exploring',
    desc:
        "Whether you're a first-time visitor or a returning explorer, welcome to Tour Tubigon.",
    image:
        'https://images.unsplash.com/photo-1549294413-26f195200c16?w=1600&h=1000&fit=crop&auto=format',
    alt: 'Tropical resort swimming pool surrounded by lush palm trees',
    accent: Color(0xFFF59E0B),
    features: [
      {
        'icon': '🔒',
        'label': 'Secure Account',
        'desc':
            'Your personal itineraries and booking history are safely synced.'
      },
      {
        'icon': '⚡',
        'label': 'Instant Access',
        'desc': 'Quick sign in with email or continue seamlessly as a guest.'
      },
      {
        'icon': '🌟',
        'label': 'Free Platform',
        'desc': 'Completely free service provided by LGU Tubigon Tourism.'
      },
      {
        'icon': '🤝',
        'label': '24/7 Support',
        'desc':
            'Helpful community and tourism staff ready to assist your journey.'
      },
    ],
  ),
];

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  late final PageController _pageController;
  final FocusNode _focusNode = FocusNode();
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  int _currentPage = 0;
  bool _obscure = true;
  bool _loading = false;
  bool _guestLoading = false;
  bool _showLoginForm = false;
  String? _errorMessage;
  String? _googleConfigurationError;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _googleEvents;

  static final RegExp _emailRegex = RegExp(r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$");

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    if (kIsWeb) _initializeGoogleForWeb();
  }

  Future<void> _initializeGoogleForWeb() async {
    try {
      await GoogleAuthService.initialize();
      _googleEvents = GoogleAuthService.authenticationEvents.listen((event) {
        if (event is GoogleSignInAuthenticationEventSignIn) {
          _completeGoogleSignIn(event.user);
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
    _pageController.dispose();
    _focusNode.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _goToPage(int pageIndex) {
    if (pageIndex < 0 || pageIndex >= _introPages.length) return;
    _pageController.animateToPage(
      pageIndex,
      duration: const Duration(milliseconds: 550),
      curve: Curves.easeInOutCubic,
    );
  }

  void _markOnboarded() {
    LocalStorageService.instance.setBool('has_onboarded', value: true);
  }

  void _showUnverifiedDialog(String email, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C2541),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.mark_email_unread_rounded,
                color: Color(0xFFF97316), size: 26),
            const SizedBox(width: 10),
            Text(
              'Email Not Verified',
              style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18),
            ),
          ],
        ),
        content: Text(
          message,
          style: GoogleFonts.inter(color: const Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: const Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF97316),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              context.go(
                  '/auth/login/verify-email?email=${Uri.encodeComponent(email)}');
            },
            child: const Text('Verify Email',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _login() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    setState(() {
      _loading = true;
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
      context.go(auth.homeRoute);
    } catch (e) {
      if (!mounted) return;
      _passwordCtrl.clear();
      if (e is UnverifiedEmailException) {
        _showUnverifiedDialog(e.email, e.message);
        setState(() => _errorMessage = e.message);
      } else {
        setState(
            () => _errorMessage = e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _continueAsGuest() async {
    if (_guestLoading) return;
    setState(() {
      _guestLoading = true;
      _errorMessage = null;
    });
    _markOnboarded();
    try {
      await ref.read(authProvider.notifier).continueAsGuest();
    } catch (_) {
      if (mounted) {
        context.go('/home');
      }
    } finally {
      if (mounted) {
        setState(() => _guestLoading = false);
      }
    }
  }

  Future<void> _googleSignIn() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      _markOnboarded();
      await ref.read(authProvider.notifier).googleSignIn();
      if (mounted) context.go(ref.read(authProvider).homeRoute);
    } catch (error) {
      if (mounted) {
        setState(() =>
            _errorMessage = error.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _completeGoogleSignIn(GoogleSignInAccount account) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      _markOnboarded();
      await ref.read(authProvider.notifier).completeGoogleSignIn(account);
      if (mounted) context.go(ref.read(authProvider).homeRoute);
    } catch (error) {
      if (mounted) {
        setState(() =>
            _errorMessage = error.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildGoogleButton({double verticalPadding = 14}) {
    if (kIsWeb) {
      if (_googleConfigurationError != null) {
        return Text(
          _googleConfigurationError!,
          textAlign: TextAlign.center,
          style:
              GoogleFonts.inter(color: const Color(0xFFEF4444), fontSize: 12),
        );
      }
      if (_loading) {
        return const Center(
            child: CircularProgressIndicator(color: Colors.white));
      }
      return Center(child: buildGoogleWebButton());
    }

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _loading ? null : _googleSignIn,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.06),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
          padding: EdgeInsets.symmetric(vertical: verticalPadding),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        icon: const Icon(Icons.g_mobiledata_rounded,
            color: Color(0xFFEA4335), size: 26),
        label: Text(
          'CONTINUE WITH GOOGLE',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }

  void _showFeatureDetails(BuildContext context, String icon, String label,
      String? desc, Color accent) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFF0A1628).withValues(alpha: 0.95),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(
                  top: BorderSide(
                      color: accent.withValues(alpha: 0.4), width: 1.5),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Text(icon, style: const TextStyle(fontSize: 28)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'TUBIGON FEATURE HIGHLIGHT',
                              style: GoogleFonts.outfit(
                                color: accent,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    desc ?? 'Discover this feature in the Tour Tubigon app.',
                    style: GoogleFonts.outfit(
                      color: Colors.white70,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'GOT IT',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final page = _introPages[_currentPage];
    final isLast = _currentPage == _introPages.length - 1;
    final screenSize = MediaQuery.of(context).size;
    final isWide = screenSize.width > 700;

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
              event.logicalKey == LogicalKeyboardKey.arrowDown) {
            _goToPage(_currentPage + 1);
          } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
              event.logicalKey == LogicalKeyboardKey.arrowUp) {
            _goToPage(_currentPage - 1);
          }
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF06101E),
        body: Stack(
          children: [
            // ── 1. Hero Background Images (PageView) ───────────────────
            Positioned.fill(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _introPages.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                    if (index != _introPages.length - 1) {
                      _showLoginForm = false;
                    }
                  });
                },
                itemBuilder: (context, index) {
                  final item = _introPages[index];
                  return AnimatedScale(
                    scale: _currentPage == index ? 1.05 : 1.0,
                    duration: const Duration(seconds: 8),
                    curve: Curves.easeOut,
                    child: CachedNetworkImage(
                      imageUrl: item.image,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: const Color(0xFF06101E),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: const Color(0xFF06101E),
                        child: const Icon(Icons.image_not_supported,
                            color: Colors.white24, size: 48),
                      ),
                    ),
                  );
                },
              ),
            ),

            // ── 2. Gradient Overlays ──────────────────────────────────
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color.fromRGBO(0, 0, 0, 0.25),
                        Colors.transparent,
                        Color.fromRGBO(0, 0, 0, 0.35),
                        Color.fromRGBO(0, 0, 0, 0.65),
                      ],
                      stops: [0.0, 0.35, 0.60, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Color.fromRGBO(0, 0, 0, 0.30),
                        Colors.transparent,
                      ],
                      stops: [0.0, 0.6],
                    ),
                  ),
                ),
              ),
            ),

            // ── 3. Ambient Dynamic Accent Glow Top-Center ─────────────
            Positioned(
              top: -40,
              left: screenSize.width / 2 - 160,
              child: IgnorePointer(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 800),
                  width: 320,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: page.accent.withValues(alpha: 0.22),
                  ),
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
                    child: Container(color: page.accent.withValues(alpha: 0.2)),
                  ),
                ),
              ),
            ),

            // ── 4. Top Header Bar ─────────────────────────────────────
            SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isWide ? 40 : 24,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Brand Badge
                    Row(
                      children: [
                        const AppLogo(size: 36, radius: 12),
                        const SizedBox(width: 10),
                        Text(
                          'TUBIGON',
                          style: GoogleFonts.dmSerifDisplay(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                            shadows: const [
                              Shadow(
                                color: Colors.black45,
                                blurRadius: 10,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Counter & Quick Sign In / Skip Button
                    Row(
                      children: [
                        Text(
                          '${(_currentPage + 1).toString().padLeft(2, '0')} / ${_introPages.length.toString().padLeft(2, '0')}',
                          style: GoogleFonts.outfit(
                            color: Colors.white.withValues(alpha: 0.45),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(width: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(30),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.2),
                                ),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(30),
                                onTap: () {
                                  if (!isLast) {
                                    _goToPage(_introPages.length - 1);
                                  }
                                  setState(() => _showLoginForm = true);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        isLast ? 'Sign In' : 'Skip →',
                                        style: GoogleFonts.outfit(
                                          color: Colors.white
                                              .withValues(alpha: 0.85),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── 5. Glassmorphic Centered Panel ──────────────────────────
            Align(
              alignment: Alignment.center,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                    child: Container(
                      width: double.infinity,
                      constraints: BoxConstraints(
                        maxWidth: isWide ? 640 : 540,
                        maxHeight: screenSize.height * 0.82,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color.fromRGBO(8, 18, 36, 0.76),
                            Color.fromRGBO(4, 10, 22, 0.94),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.10),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Accent Shimmer Top Line
                          Center(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 500),
                              width: 60,
                              height: 2,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(1),
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.transparent,
                                    page.accent.withValues(alpha: 0.8),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // Panel Scrollable Content Area
                          Expanded(
                            child: SafeArea(
                              top: false,
                              bottom: false,
                              child: SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                padding: EdgeInsets.fromLTRB(
                                  isWide ? 40 : 24,
                                  24,
                                  isWide ? 40 : 24,
                                  16,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // ── Tag Pill ────────────────────────
                                    AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 400),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 7,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            page.accent.withValues(alpha: 0.14),
                                        borderRadius: BorderRadius.circular(24),
                                        border: Border.all(
                                          color: page.accent
                                              .withValues(alpha: 0.45),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: page.accent,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            _showLoginForm
                                                ? 'SIGN IN'
                                                : page.tag,
                                            style: GoogleFonts.outfit(
                                              color: page.accent,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 2.2,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    const SizedBox(height: 14),

                                    // ── Headline & Subheadline ──────────
                                    Text(
                                      _showLoginForm
                                          ? 'Welcome Back'
                                          : page.headline,
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.dmSerifDisplay(
                                        color: Colors.white,
                                        fontSize: isWide ? 40 : 34,
                                        height: 1.15,
                                        letterSpacing: 0,
                                        shadows: const [
                                          Shadow(
                                            color: Colors.black38,
                                            blurRadius: 18,
                                            offset: Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                    )
                                        .animate(
                                            key: ValueKey(
                                                'hl_${page.id}_$_showLoginForm'))
                                        .fadeIn(duration: 400.ms)
                                        .slideY(
                                            begin: 0.15,
                                            end: 0,
                                            duration: 400.ms),

                                    const SizedBox(height: 6),

                                    Text(
                                      (_showLoginForm
                                              ? 'Enter your credentials to continue'
                                              : page.sub)
                                          .toUpperCase(),
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.outfit(
                                        color: Colors.white
                                            .withValues(alpha: 0.55),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 2.2,
                                      ),
                                    ),

                                    const SizedBox(height: 14),

                                    // ── Description ────────────────────
                                    if (!_showLoginForm) ...[
                                      Text(
                                        page.desc,
                                        textAlign: TextAlign.justify,
                                        style: GoogleFonts.outfit(
                                          color: Colors.white
                                              .withValues(alpha: 0.85),
                                          fontSize: 16,
                                          height: 1.6,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                      const SizedBox(height: 18),
                                    ],

                                    // ── Page Feature Cards Grid ─────
                                    if (!_showLoginForm &&
                                        page.features != null) ...[
                                      GridView.builder(
                                        shrinkWrap: true,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        gridDelegate:
                                            const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 4,
                                          mainAxisSpacing: 8,
                                          crossAxisSpacing: 8,
                                          childAspectRatio: 0.95,
                                        ),
                                        itemCount: page.features!.length,
                                        itemBuilder: (context, idx) {
                                          final item = page.features![idx];
                                          return _GlassFeatureCard(
                                            icon: item['icon']!,
                                            label: item['label']!,
                                            onTap: () => _showFeatureDetails(
                                              context,
                                              item['icon']!,
                                              item['label']!,
                                              item['desc'],
                                              page.accent,
                                            ),
                                          );
                                        },
                                      ),
                                      const SizedBox(height: 16),
                                    ],

                                    // ── Categories Grid ─────────
                                    if (!_showLoginForm &&
                                        page.categories != null) ...[
                                      GridView.builder(
                                        shrinkWrap: true,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        gridDelegate:
                                            SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: isWide ? 6 : 3,
                                          mainAxisSpacing: 8,
                                          crossAxisSpacing: 8,
                                          childAspectRatio: 1.1,
                                        ),
                                        itemCount: page.categories!.length,
                                        itemBuilder: (context, idx) {
                                          final item = page.categories![idx];
                                          return _GlassFeatureCard(
                                            icon: item['icon']!,
                                            label: item['label']!,
                                            smallText: true,
                                            onTap: () => _showFeatureDetails(
                                              context,
                                              item['icon']!,
                                              item['label']!,
                                              item['desc'],
                                              page.accent,
                                            ),
                                          );
                                        },
                                      ),
                                      const SizedBox(height: 16),
                                    ],

                                    // ── Smart Feature Pills ─────
                                    if (!_showLoginForm &&
                                        page.smartFeatures != null) ...[
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children:
                                            page.smartFeatures!.map((item) {
                                          return _GlassPill(
                                            icon: item['icon']!,
                                            label: item['label']!,
                                            onTap: () => _showFeatureDetails(
                                              context,
                                              item['icon']!,
                                              item['label']!,
                                              item['desc'],
                                              page.accent,
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                      const SizedBox(height: 16),
                                    ],

                                    // ── Direct Sign In Form View ───────
                                    if (_showLoginForm) ...[
                                      Form(
                                        key: _formKey,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            // Error Banner
                                            if (_errorMessage != null) ...[
                                              Container(
                                                padding:
                                                    const EdgeInsets.all(10),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFEF4444)
                                                      .withValues(alpha: 0.15),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color:
                                                        const Color(0xFFEF4444)
                                                            .withValues(
                                                                alpha: 0.4),
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    const Icon(
                                                      Icons
                                                          .error_outline_rounded,
                                                      color: Color(0xFFEF4444),
                                                      size: 18,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        _errorMessage!,
                                                        style:
                                                            GoogleFonts.outfit(
                                                          color: const Color(
                                                              0xFFF87171),
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                            ],

                                            // Email Input
                                            TextFormField(
                                              controller: _emailCtrl,
                                              enabled:
                                                  !_loading && !_guestLoading,
                                              keyboardType:
                                                  TextInputType.emailAddress,
                                              style: GoogleFonts.outfit(
                                                  color: Colors.white,
                                                  fontSize: 14),
                                              decoration: InputDecoration(
                                                labelText: 'Email Address',
                                                labelStyle: GoogleFonts.outfit(
                                                    color: Colors.white60),
                                                prefixIcon: const Icon(
                                                    Icons.email_outlined,
                                                    color: Colors.white60),
                                                filled: true,
                                                fillColor: Colors.white
                                                    .withValues(alpha: 0.06),
                                                enabledBorder:
                                                    OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                  borderSide: BorderSide(
                                                    color: Colors.white
                                                        .withValues(
                                                            alpha: 0.15),
                                                  ),
                                                ),
                                                focusedBorder:
                                                    OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                  borderSide: BorderSide(
                                                    color: page.accent,
                                                    width: 1.5,
                                                  ),
                                                ),
                                              ),
                                              validator: (v) {
                                                final trimmed = v?.trim() ?? '';
                                                if (trimmed.isEmpty) {
                                                  return 'Enter your email';
                                                }
                                                if (!_emailRegex
                                                    .hasMatch(trimmed)) {
                                                  return 'Enter a valid email address';
                                                }
                                                return null;
                                              },
                                            ),
                                            const SizedBox(height: 12),

                                            // Password Input
                                            TextFormField(
                                              controller: _passwordCtrl,
                                              enabled:
                                                  !_loading && !_guestLoading,
                                              obscureText: _obscure,
                                              style: GoogleFonts.outfit(
                                                  color: Colors.white,
                                                  fontSize: 14),
                                              decoration: InputDecoration(
                                                labelText: 'Password',
                                                labelStyle: GoogleFonts.outfit(
                                                    color: Colors.white60),
                                                prefixIcon: const Icon(
                                                    Icons.lock_outline_rounded,
                                                    color: Colors.white60),
                                                suffixIcon: IconButton(
                                                  icon: Icon(
                                                    _obscure
                                                        ? Icons
                                                            .visibility_outlined
                                                        : Icons
                                                            .visibility_off_outlined,
                                                    color: Colors.white60,
                                                  ),
                                                  onPressed: () => setState(
                                                      () =>
                                                          _obscure = !_obscure),
                                                ),
                                                filled: true,
                                                fillColor: Colors.white
                                                    .withValues(alpha: 0.06),
                                                enabledBorder:
                                                    OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                  borderSide: BorderSide(
                                                    color: Colors.white
                                                        .withValues(
                                                            alpha: 0.15),
                                                  ),
                                                ),
                                                focusedBorder:
                                                    OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                  borderSide: BorderSide(
                                                    color: page.accent,
                                                    width: 1.5,
                                                  ),
                                                ),
                                              ),
                                              validator: (v) {
                                                if (v == null || v.isEmpty) {
                                                  return 'Enter your password';
                                                }
                                                if (v.length < 6) {
                                                  return 'Password must be at least 6 characters';
                                                }
                                                return null;
                                              },
                                            ),
                                            const SizedBox(height: 6),

                                            // Forgot Password
                                            Align(
                                              alignment: Alignment.centerRight,
                                              child: TextButton(
                                                onPressed: () =>
                                                    context.goNamed(RouteNames
                                                        .forgotPassword),
                                                child: Text(
                                                  'Forgot Password?',
                                                  style: GoogleFonts.outfit(
                                                    color: page.accent,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 8),

                                            // Submit Login Button
                                            SizedBox(
                                              width: double.infinity,
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                  gradient: LinearGradient(
                                                    colors: [
                                                      page.accent,
                                                      const Color(0xFFF97316),
                                                    ],
                                                  ),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: page.accent
                                                          .withValues(
                                                              alpha: 0.35),
                                                      blurRadius: 20,
                                                      offset:
                                                          const Offset(0, 8),
                                                    ),
                                                  ],
                                                ),
                                                child: ElevatedButton(
                                                  onPressed:
                                                      _loading || _guestLoading
                                                          ? null
                                                          : _login,
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        Colors.transparent,
                                                    shadowColor:
                                                        Colors.transparent,
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        vertical: 14),
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              16),
                                                    ),
                                                  ),
                                                  child: _loading
                                                      ? const SizedBox(
                                                          height: 20,
                                                          width: 20,
                                                          child:
                                                              CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                            color: Colors.white,
                                                          ),
                                                        )
                                                      : Text(
                                                          'SIGN IN',
                                                          style: GoogleFonts
                                                              .outfit(
                                                            color: Colors.white,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 13,
                                                            letterSpacing: 1.5,
                                                          ),
                                                        ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 10),

                                            // OR Divider
                                            Row(
                                              children: [
                                                const Expanded(
                                                    child: Divider(
                                                        color: Colors.white24,
                                                        height: 1)),
                                                Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 12),
                                                  child: Text(
                                                    'OR',
                                                    style: GoogleFonts.outfit(
                                                        color: Colors.white54,
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w600),
                                                  ),
                                                ),
                                                const Expanded(
                                                    child: Divider(
                                                        color: Colors.white24,
                                                        height: 1)),
                                              ],
                                            ),
                                            const SizedBox(height: 10),

                                            // Official Google Sign In Button
                                            _buildGoogleButton(),
                                            const SizedBox(height: 8),

                                            // Back to Intro Overview
                                            TextButton(
                                              onPressed: () => setState(
                                                  () => _showLoginForm = false),
                                              child: Text(
                                                '← Back to Intro Highlights',
                                                style: GoogleFonts.outfit(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.50),
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                    ],

                                    // ── Page 4: CTA Action Buttons (Default View) ─────
                                    if (!_showLoginForm && isLast) ...[
                                      Column(
                                        children: [
                                          // Primary Sign In Button
                                          SizedBox(
                                            width: double.infinity,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                gradient: const LinearGradient(
                                                  colors: [
                                                    Color(0xFFF59E0B),
                                                    Color(0xFFF97316),
                                                  ],
                                                ),
                                                boxShadow: const [
                                                  BoxShadow(
                                                    color: Color.fromRGBO(
                                                        245, 158, 11, 0.35),
                                                    blurRadius: 20,
                                                    offset: Offset(0, 8),
                                                  ),
                                                ],
                                              ),
                                              child: ElevatedButton(
                                                onPressed: () => setState(() =>
                                                    _showLoginForm = true),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      Colors.transparent,
                                                  shadowColor:
                                                      Colors.transparent,
                                                  padding: const EdgeInsets
                                                      .symmetric(vertical: 14),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            16),
                                                  ),
                                                ),
                                                child: Text(
                                                  'SIGN IN WITH EMAIL',
                                                  style: GoogleFonts.outfit(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                    letterSpacing: 1.5,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 10),

                                          // Secondary: Create Account
                                          SizedBox(
                                            width: double.infinity,
                                            child: OutlinedButton(
                                              onPressed: () {
                                                _markOnboarded();
                                                context.goNamed(
                                                    RouteNames.register);
                                              },
                                              style: OutlinedButton.styleFrom(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 14),
                                                side: BorderSide(
                                                  color: page.accent,
                                                  width: 1.5,
                                                ),
                                                backgroundColor: page.accent
                                                    .withValues(alpha: 0.12),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                ),
                                              ),
                                              child: Text(
                                                'CREATE ACCOUNT',
                                                style: GoogleFonts.outfit(
                                                  color: page.accent,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                  letterSpacing: 1.5,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 10),

                                          // Official Google Sign In
                                          _buildGoogleButton(),
                                          const SizedBox(height: 8),

                                          // Tertiary: Explore as Guest
                                          TextButton(
                                            onPressed: _guestLoading
                                                ? null
                                                : _continueAsGuest,
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                if (_guestLoading)
                                                  const SizedBox(
                                                    width: 14,
                                                    height: 14,
                                                    child:
                                                        CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.white70,
                                                    ),
                                                  )
                                                else ...[
                                                  Text(
                                                    'EXPLORE AS GUEST',
                                                    style: GoogleFonts.outfit(
                                                      color: Colors.white
                                                          .withValues(
                                                              alpha: 0.60),
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 12,
                                                      letterSpacing: 1.5,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    '→',
                                                    style: GoogleFonts.outfit(
                                                      color: Colors.white
                                                          .withValues(
                                                              alpha: 0.60),
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // ── 6. Fixed Bottom Navigation Control Bar ────
                          if (!_showLoginForm)
                            SafeArea(
                              top: false,
                              child: Container(
                                padding: EdgeInsets.fromLTRB(
                                  isWide ? 40 : 24,
                                  12,
                                  isWide ? 40 : 24,
                                  16,
                                ),
                                decoration: BoxDecoration(
                                  border: Border(
                                    top: BorderSide(
                                      color:
                                          Colors.white.withValues(alpha: 0.08),
                                      width: 1,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Indicator Dots
                                    Row(
                                      children: List.generate(
                                        _introPages.length,
                                        (index) => GestureDetector(
                                          onTap: () => _goToPage(index),
                                          child: AnimatedContainer(
                                            duration: const Duration(
                                                milliseconds: 350),
                                            margin:
                                                const EdgeInsets.only(right: 6),
                                            width:
                                                _currentPage == index ? 24 : 7,
                                            height: 7,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              color: _currentPage == index
                                                  ? page.accent
                                                  : Colors.white
                                                      .withValues(alpha: 0.28),
                                              boxShadow: _currentPage == index
                                                  ? [
                                                      BoxShadow(
                                                        color: page.accent
                                                            .withValues(
                                                                alpha: 0.5),
                                                        blurRadius: 8,
                                                      )
                                                    ]
                                                  : null,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),

                                    // Next / Prev Arrow Buttons
                                    Row(
                                      children: [
                                        if (_currentPage > 0) ...[
                                          InkWell(
                                            borderRadius:
                                                BorderRadius.circular(30),
                                            onTap: () =>
                                                _goToPage(_currentPage - 1),
                                            child: AnimatedContainer(
                                              duration: const Duration(
                                                  milliseconds: 300),
                                              width: 40,
                                              height: 40,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: page.accent
                                                    .withValues(alpha: 0.10),
                                                border: Border.all(
                                                  color: page.accent
                                                      .withValues(alpha: 0.25),
                                                ),
                                              ),
                                              child: const Center(
                                                child: Text(
                                                  '←',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                        ],
                                        if (!isLast) ...[
                                          AnimatedContainer(
                                            duration: const Duration(
                                                milliseconds: 400),
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(30),
                                              gradient: LinearGradient(
                                                colors: [
                                                  page.accent,
                                                  page.accent
                                                      .withValues(alpha: 0.82),
                                                ],
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: page.accent
                                                      .withValues(alpha: 0.45),
                                                  blurRadius: 14,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            child: Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                borderRadius:
                                                    BorderRadius.circular(30),
                                                onTap: () =>
                                                    _goToPage(_currentPage + 1),
                                                child: Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 20,
                                                    vertical: 10,
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        'Next',
                                                        style:
                                                            GoogleFonts.outfit(
                                                          color: Colors.white,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 13,
                                                          letterSpacing: 0.5,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      const Text(
                                                        '→',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
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
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassFeatureCard extends StatelessWidget {
  final String icon;
  final String label;
  final bool smallText;
  final VoidCallback? onTap;

  const _GlassFeatureCard({
    required this.icon,
    required this.label,
    this.smallText = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            splashColor: Colors.white10,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.11),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    icon,
                    style: TextStyle(fontSize: smallText ? 20 : 24),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      color: Colors.white.withValues(alpha: 0.82),
                      fontSize: smallText ? 9 : 10,
                      fontWeight: FontWeight.w500,
                      height: 1.1,
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

class _GlassPill extends StatelessWidget {
  final String icon;
  final String label;
  final VoidCallback? onTap;

  const _GlassPill({
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            splashColor: Colors.white10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.13),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(icon, style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: GoogleFonts.outfit(
                      color: Colors.white.withValues(alpha: 0.82),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
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
