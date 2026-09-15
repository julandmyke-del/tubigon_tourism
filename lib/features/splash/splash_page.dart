import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/widgets/app_logo.dart';
import '../authentication/auth_provider.dart';

// ─── Particle Data ───────────────────────────────────────────────────────────
class _ParticleData {
  final int id;
  final double leftPercent;
  final double bottomPercent;
  final double size;
  final double delaySeconds;
  final double durationSeconds;
  final double dx;
  final Color color;

  const _ParticleData({
    required this.id,
    required this.leftPercent,
    required this.bottomPercent,
    required this.size,
    required this.delaySeconds,
    required this.durationSeconds,
    required this.dx,
    required this.color,
  });
}

// ─── Sparkle Data ────────────────────────────────────────────────────────────
class _SparkleData {
  final int id;
  final double topPercent;
  final double leftPercent;
  final double size;
  final double delaySeconds;
  final double durationSeconds;

  const _SparkleData({
    required this.id,
    required this.topPercent,
    required this.leftPercent,
    required this.size,
    required this.delaySeconds,
    required this.durationSeconds,
  });
}

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage>
    with TickerProviderStateMixin {
  late final AnimationController _gridController;
  late final AnimationController _orbitController;
  late final AnimationController _glowController;
  late final AnimationController _waveController;
  late final AnimationController _birdController;

  static const _particlesCount = 28;
  late final List<_ParticleData> _particles;
  late final List<_SparkleData> _sparkles;

  static const _barDelays = [
    0.0,
    0.11,
    0.22,
    0.33,
    0.44,
    0.55,
    0.44,
    0.33,
    0.22,
    0.11,
    0.0
  ];
  static const _barHeights = [
    6.0,
    10.0,
    16.0,
    22.0,
    28.0,
    32.0,
    28.0,
    22.0,
    16.0,
    10.0,
    6.0
  ];

  @override
  void initState() {
    super.initState();

    _gridController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 28),
    )..repeat();

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat(reverse: true);

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();

    _birdController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();

    // Generate static particle data
    _particles = List.generate(_particlesCount, (i) {
      final hueColor = i % 4 == 0
          ? const Color(0xFFF97316)
          : i % 4 == 1
              ? const Color(0xFF38BDF8)
              : i % 4 == 2
                  ? const Color(0xFFA7F3D0)
                  : const Color(0xFFFBBF24);

      return _ParticleData(
        id: i,
        leftPercent: (4 + (i * 37 + 11) % 92) / 100.0,
        bottomPercent: (2 + (i * 19) % 42) / 100.0,
        size: 1.5 + (i % 4) * 0.7,
        delaySeconds: ((i * 0.31) % 5),
        durationSeconds: 4.2 + (i * 0.55) % 4.5,
        dx: -16.0 + (i % 5) * 8.0,
        color: hueColor,
      );
    });

    _sparkles = List.generate(10, (i) {
      return _SparkleData(
        id: i,
        topPercent: (8 + (i * 29) % 72) / 100.0,
        leftPercent: (6 + (i * 41) % 88) / 100.0,
        size: 3.0 + (i % 3),
        delaySeconds: i * 0.6,
        durationSeconds: 2.6 + i * 0.25,
      );
    });

    _navigate();
  }

  bool _navigated = false;

  Future<void> _navigate() async {
    if (_navigated) return;

    // Minimum delay for splash animation (2.0 seconds)
    await Future.delayed(const Duration(milliseconds: 2000));
    if (!mounted || _navigated) return;

    // Fast 1.5s max timeout on reloadProfile so splash screen NEVER freezes
    try {
      await ref.read(authProvider.notifier).reloadProfile().timeout(
        const Duration(milliseconds: 1500),
        onTimeout: () {
          debugPrint(
              '[SPLASH] reloadProfile timed out — using local auth state');
        },
      );
    } catch (e) {
      debugPrint('[SPLASH] reloadProfile error: $e');
    }

    if (!mounted || _navigated) return;
    _navigated = true;

    final authState = ref.read(authProvider);
    debugPrint(
        '[SPLASH] Navigating: isAuthenticated=${authState.isAuthenticated}, role=${authState.role}');

    if (authState.isAuthenticated) {
      context.go(authState.homeRoute);
    } else {
      context.go('/onboarding');
    }
  }

  @override
  void dispose() {
    _gridController.dispose();
    _orbitController.dispose();
    _glowController.dispose();
    _waveController.dispose();
    _birdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF080D1A),
      body: Stack(
        children: [
          // ── 1. Animated Perspective Grid Background ───────────────
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _gridController,
              builder: (context, child) {
                return CustomPaint(
                  size: Size.infinite,
                  painter: _GridBackgroundPainter(
                    progress: _gridController.value,
                  ),
                );
              },
            ),
          ),

          // Grid Top & Bottom Vignette Fade
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF080D1A),
                      Colors.transparent,
                      Colors.transparent,
                      Color(0xFF080D1A),
                    ],
                    stops: [0.0, 0.25, 0.75, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // ── 2. Radial Center Deep Navy Glow ───────────────────────
          Positioned(
            top: screenSize.height * 0.5 - 280,
            left: screenSize.width * 0.5 - 280,
            child: Container(
              width: 560,
              height: 560,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color.fromRGBO(17, 29, 53, 0.95),
                    Color.fromRGBO(8, 13, 26, 0),
                  ],
                  stops: [0.0, 0.7],
                ),
              ),
            ),
          ),

          // ── 3. Top Orange Accent Glow ──────────────────────────────
          Positioned(
            top: -60,
            left: screenSize.width * 0.5 - 220,
            child: AnimatedBuilder(
              animation: _glowController,
              builder: (context, child) {
                final scale = 1.0 + _glowController.value * 0.08;
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 440,
                    height: 280,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFFF97316).withValues(alpha: 0.16),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.65],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // ── 4. Bottom Navy-Blue Accent Glow ───────────────────────
          Positioned(
            bottom: -60,
            left: screenSize.width * 0.5 - 260,
            child: AnimatedBuilder(
              animation: _glowController,
              builder: (context, child) {
                final scale = 1.0 + (1.0 - _glowController.value) * 0.12;
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 520,
                    height: 280,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFF1D4ED8).withValues(alpha: 0.18),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.65],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // ── 5. Horizon Line & Vector Skyline Silhouette ───────────
          Positioned(
            bottom: screenSize.height * 0.17,
            left: 0,
            right: 0,
            height: 160,
            child: IgnorePointer(
              child: CustomPaint(
                size: Size.infinite,
                painter: _SkylinePainter(),
              ),
            ),
          ),

          // Horizon Divider Line
          Positioned(
            bottom: screenSize.height * 0.18,
            left: 0,
            right: 0,
            child: Container(
              height: 1,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Color.fromRGBO(249, 115, 22, 0.25),
                    Color.fromRGBO(249, 115, 22, 0.50),
                    Color.fromRGBO(249, 115, 22, 0.25),
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.3, 0.5, 0.7, 1.0],
                ),
              ),
            ),
          ),

          // Water Reflection Glow
          Positioned(
            bottom: screenSize.height * 0.12,
            left: screenSize.width * 0.2,
            right: screenSize.width * 0.2,
            height: 30,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      Color.fromRGBO(249, 115, 22, 0.15),
                      Colors.transparent,
                    ],
                    stops: [0.0, 0.7],
                  ),
                ),
              ),
            ),
          ),

          // ── 6. Flying Birds Silhouettes ────────────────────────────
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _birdController,
              builder: (context, child) {
                final progress = _birdController.value;
                final bird1X = (progress * (screenSize.width + 200)) - 100;
                final bird2X =
                    (((progress + 0.4) % 1.0) * (screenSize.width + 200)) - 100;

                return Stack(
                  children: [
                    Positioned(
                      top: screenSize.height * 0.13,
                      left: bird1X,
                      child: CustomPaint(
                        size: const Size(60, 16),
                        painter: _BirdPainter(opacity: 0.7),
                      ),
                    ),
                    Positioned(
                      top: screenSize.height * 0.20,
                      left: bird2X,
                      child: CustomPaint(
                        size: const Size(42, 12),
                        painter: _BirdPainter(opacity: 0.5),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // ── 7. Floating Rising Particles ──────────────────────────
          ..._particles.map((p) {
            return Positioned(
              left: screenSize.width * p.leftPercent,
              bottom: screenSize.height * p.bottomPercent,
              child: _RisingParticleWidget(particle: p),
            );
          }),

          // ── 8. Star Sparkles ───────────────────────────────────────
          ..._sparkles.map((s) {
            return Positioned(
              top: screenSize.height * s.topPercent,
              left: screenSize.width * s.leftPercent,
              child: _SparkleWidget(sparkle: s),
            );
          }),

          // ── 9. Main Center Content Area ───────────────────────────
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // ── Logo Mark ───────────────────────────────
                      const AppLogo(size: 136, radius: 24)
                          .animate()
                          .fadeIn(duration: 900.ms, delay: 200.ms)
                          .scale(duration: 900.ms, curve: Curves.easeOutBack),

                      const SizedBox(height: 28),

                      // ── App Name Headline ───────────────────────
                      Text(
                        'TUBIGON',
                        style: GoogleFonts.playfairDisplay(
                          color: const Color(0xFFF1F5F9),
                          fontSize: screenSize.width > 600 ? 50 : 38,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 6.0,
                          height: 1.05,
                          shadows: const [
                            Shadow(
                              color: Color.fromRGBO(249, 115, 22, 0.4),
                              blurRadius: 30,
                            ),
                            Shadow(
                              color: Colors.black54,
                              blurRadius: 16,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                      )
                          .animate()
                          .fadeIn(duration: 800.ms, delay: 400.ms)
                          .slideY(
                              begin: 0.3,
                              end: 0,
                              duration: 800.ms,
                              curve: Curves.easeOutCubic),

                      const SizedBox(height: 4),

                      Text(
                        'TOURISM',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFFF97316),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 7.0,
                          shadows: const [
                            Shadow(
                              color: Color.fromRGBO(249, 115, 22, 0.5),
                              blurRadius: 16,
                            ),
                          ],
                        ),
                      )
                          .animate()
                          .fadeIn(duration: 800.ms, delay: 600.ms)
                          .slideY(
                              begin: 0.3,
                              end: 0,
                              duration: 800.ms,
                              curve: Curves.easeOutCubic),

                      const SizedBox(height: 16),

                      // ── Accent Divider Line ─────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 40,
                            height: 1,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  Color.fromRGBO(249, 115, 22, 0.5),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFFF97316),
                              boxShadow: [
                                BoxShadow(
                                  color: Color.fromRGBO(249, 115, 22, 0.8),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 40,
                            height: 1,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Color.fromRGBO(249, 115, 22, 0.5),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ],
                      ).animate().fadeIn(duration: 700.ms, delay: 800.ms),

                      const SizedBox(height: 12),

                      // ── Tagline ─────────────────────────────────
                      Text(
                        'DISCOVER EVERY JOURNEY',
                        style: GoogleFonts.outfit(
                          color: const Color.fromRGBO(148, 163, 184, 0.9),
                          fontSize: 12,
                          fontWeight: FontWeight.w300,
                          letterSpacing: 3.0,
                        ),
                      ).animate().fadeIn(duration: 700.ms, delay: 950.ms),

                      const SizedBox(height: 24),

                      // ── Feature / Role Chips ─────────────────────
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: ['Explore', 'Reserve', 'Discover', 'Connect']
                            .map((label) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color.fromRGBO(
                                        249, 115, 22, 0.06),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: const Color.fromRGBO(
                                          249, 115, 22, 0.22),
                                    ),
                                  ),
                                  child: Text(
                                    label.toUpperCase(),
                                    style: GoogleFonts.outfit(
                                      color: const Color.fromRGBO(
                                          148, 163, 184, 0.85),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ))
                            .toList(),
                      ).animate().fadeIn(duration: 700.ms, delay: 1100.ms),

                      const SizedBox(height: 36),

                      // ── Wave Equalizer Bar Loader ───────────────
                      AnimatedBuilder(
                        animation: _waveController,
                        builder: (context, child) {
                          return SizedBox(
                            height: 36,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: List.generate(11, (idx) {
                                final delay = _barDelays[idx];
                                final targetHeight = _barHeights[idx];

                                final waveVal = math.sin(
                                  (_waveController.value * 2 * math.pi) -
                                      (delay * 4),
                                );
                                final scaleY =
                                    0.35 + (0.65 * (waveVal + 1) / 2);
                                final h = targetHeight * scaleY;

                                final barColor = idx == 5
                                    ? const Color(0xFFF97316)
                                    : (idx == 4 || idx == 6)
                                        ? const Color.fromRGBO(
                                            249, 115, 22, 0.75)
                                        : (idx == 3 || idx == 7)
                                            ? const Color.fromRGBO(
                                                249, 115, 22, 0.50)
                                            : const Color.fromRGBO(
                                                249, 115, 22, 0.28);

                                return Container(
                                  width: 3,
                                  height: h,
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 2),
                                  decoration: BoxDecoration(
                                    color: barColor,
                                    borderRadius: BorderRadius.circular(3),
                                    boxShadow: (idx >= 4 && idx <= 6)
                                        ? [
                                            BoxShadow(
                                              color: const Color(0xFFF97316)
                                                  .withValues(alpha: 0.6),
                                              blurRadius: 8,
                                            ),
                                          ]
                                        : null,
                                  ),
                                );
                              }),
                            ),
                          );
                        },
                      ).animate().fadeIn(duration: 700.ms, delay: 1250.ms),

                      const SizedBox(height: 20),

                      // ── Version Footer Tag ──────────────────────
                      Text(
                        'V1.0 · TOURISM INFORMATION SYSTEM',
                        style: GoogleFonts.outfit(
                          color: const Color.fromRGBO(71, 85, 105, 0.8),
                          fontSize: 10,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 2.0,
                        ),
                      ).animate().fadeIn(duration: 700.ms, delay: 1400.ms),
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

// ─── Grid Background Painter ──────────────────────────────────────────────────
class _GridBackgroundPainter extends CustomPainter {
  final double progress;

  _GridBackgroundPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color.fromRGBO(249, 115, 22, 0.04)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    const step = 60.0;
    final offsetY = (progress * step);

    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = -step + offsetY; y <= size.height + step; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridBackgroundPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

// ─── Skyline Vector Silhouette Painter ────────────────────────────────────────
class _SkylinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / 1440.0;
    final scaleY = size.height / 200.0;

    final buildingPaint1 = Paint()..color = const Color(0xFF1C2A50);
    final buildingPaint2 = Paint()..color = const Color(0xFF162040);
    final buildingPaint3 = Paint()..color = const Color(0xFF111D35);
    final windowPaint = Paint()
      ..color = const Color.fromRGBO(249, 115, 22, 0.50);
    final antennaPaint = Paint()
      ..color = const Color.fromRGBO(249, 115, 22, 0.80);

    void drawBldg(double x, double y, double w, double h, Paint p) {
      canvas.drawRect(
        Rect.fromLTWH(x * scaleX, y * scaleY, w * scaleX, h * scaleY),
        p,
      );
    }

    void drawAntenna(double x, double y, double w, double h) {
      canvas.drawRect(
        Rect.fromLTWH(x * scaleX, y * scaleY, w * scaleX, h * scaleY),
        antennaPaint,
      );
    }

    // Render Buildings
    drawBldg(60, 100, 40, 100, buildingPaint1);
    drawBldg(65, 80, 30, 20, buildingPaint1);
    drawAntenna(78, 68, 6, 14);

    drawBldg(110, 120, 55, 80, buildingPaint2);
    drawBldg(125, 105, 25, 16, buildingPaint2);

    drawBldg(175, 90, 50, 110, buildingPaint1);
    drawBldg(185, 78, 30, 14, buildingPaint1);
    drawAntenna(198, 65, 4, 14);

    drawBldg(235, 130, 60, 70, buildingPaint3);
    drawBldg(305, 110, 45, 90, buildingPaint2);
    drawBldg(315, 95, 25, 16, buildingPaint2);

    drawBldg(360, 75, 70, 125, buildingPaint1);
    drawBldg(375, 60, 40, 16, buildingPaint1);
    drawAntenna(392, 46, 6, 15);

    drawBldg(440, 115, 50, 85, buildingPaint2);
    drawBldg(500, 95, 65, 105, buildingPaint3);
    drawBldg(515, 78, 35, 18, buildingPaint3);
    drawAntenna(530, 63, 5, 16);

    drawBldg(575, 130, 55, 70, buildingPaint1);
    drawBldg(640, 85, 80, 115, buildingPaint2);
    drawBldg(655, 68, 50, 18, buildingPaint2);
    drawAntenna(677, 53, 6, 16);

    drawBldg(730, 120, 45, 80, buildingPaint3);
    drawBldg(785, 100, 60, 100, buildingPaint1);
    drawBldg(855, 140, 50, 60, buildingPaint2);
    drawBldg(915, 105, 70, 95, buildingPaint3);
    drawBldg(930, 88, 40, 18, buildingPaint3);
    drawAntenna(947, 73, 6, 16);

    drawBldg(995, 125, 55, 75, buildingPaint1);
    drawBldg(1060, 90, 75, 110, buildingPaint2);
    drawBldg(1075, 73, 45, 18, buildingPaint2);
    drawAntenna(1094, 58, 7, 16);

    drawBldg(1145, 115, 55, 85, buildingPaint3);
    drawBldg(1210, 100, 60, 100, buildingPaint1);
    drawBldg(1280, 130, 50, 70, buildingPaint2);
    drawBldg(1340, 110, 60, 90, buildingPaint3);

    // Glowing Orange Windows
    final bldgPositions = [190.0, 370.0, 515.0, 645.0, 920.0, 1065.0];
    for (final bx in bldgPositions) {
      for (int r = 0; r < 4; r++) {
        for (int c = 0; c < 3; c++) {
          final wx = (bx + 6 + c * 9) * scaleX;
          final wy = (90 + r * 14) * scaleY;
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(wx, wy, 5 * scaleX, 7 * scaleY),
              const Radius.circular(1),
            ),
            windowPaint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Compass Logo Mark Painter ────────────────────────────────────────────────
// Kept temporarily for backwards-compatible splash theming references.
// ignore: unused_element
class _CompassLogoPainter extends CustomPainter {
  final double orbitAngle;

  _CompassLogoPainter({required this.orbitAngle});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // 1. Outermost faint ring
    final faintPaint = Paint()
      ..color = const Color.fromRGBO(249, 115, 22, 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawCircle(center, 58, faintPaint);

    // 2. Orbit Rings (Dashed Circles)
    _drawDashedCircle(canvas, center, 52, 12, 8,
        const Color.fromRGBO(249, 115, 22, 0.25), orbitAngle);
    _drawDashedCircle(canvas, center, 46, 6, 14,
        const Color.fromRGBO(56, 189, 248, 0.20), -orbitAngle * 1.4);
    _drawDashedCircle(canvas, center, 38, 3, 9,
        const Color.fromRGBO(249, 115, 22, 0.18), orbitAngle * 0.8);

    // 3. Inner Dark Disc
    final discBgPaint = Paint()
      ..color = const Color.fromRGBO(17, 29, 53, 0.90)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 32, discBgPaint);

    final discBorderPaint = Paint()
      ..color = const Color.fromRGBO(249, 115, 22, 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, 32, discBorderPaint);

    // 4. Compass Axis Lines
    final axisPaint = Paint()
      ..color = const Color.fromRGBO(249, 115, 22, 0.28)
      ..strokeWidth = 0.8;
    canvas.drawLine(Offset(center.dx, center.dy - 30),
        Offset(center.dx, center.dy + 30), axisPaint);
    canvas.drawLine(Offset(center.dx - 30, center.dy),
        Offset(center.dx + 30, center.dy), axisPaint);

    // 5. Outer Tick Marks
    final tickMajorPaint = Paint()
      ..color = const Color.fromRGBO(249, 115, 22, 0.55)
      ..strokeWidth = 1.0;
    final tickMinorPaint = Paint()
      ..color = const Color.fromRGBO(249, 115, 22, 0.18)
      ..strokeWidth = 0.6;
    for (int i = 0; i < 24; i++) {
      final ang = (i * 15 * math.pi) / 180;
      final r1 = i % 6 == 0 ? 54.0 : (i % 3 == 0 ? 55.0 : 56.0);
      final p1 = Offset(
          center.dx + math.cos(ang) * r1, center.dy + math.sin(ang) * r1);
      final p2 = Offset(
          center.dx + math.cos(ang) * 58.0, center.dy + math.sin(ang) * 58.0);
      canvas.drawLine(p1, p2, i % 6 == 0 ? tickMajorPaint : tickMinorPaint);
    }

    // 6. Cardinal Letters (N, E, S, W)
    final textPainterN = TextPainter(
      text: TextSpan(
        text: 'N',
        style: GoogleFonts.outfit(
          color: const Color.fromRGBO(249, 115, 22, 0.85),
          fontSize: 7,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainterN.paint(
        canvas, Offset(center.dx - textPainterN.width / 2, center.dy - 44));

    final textPainterE = TextPainter(
      text: TextSpan(
        text: 'E',
        style: GoogleFonts.outfit(
          color: const Color.fromRGBO(148, 163, 184, 0.65),
          fontSize: 6,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainterE.paint(
        canvas, Offset(center.dx + 40, center.dy - textPainterE.height / 2));

    final textPainterS = TextPainter(
      text: TextSpan(
        text: 'S',
        style: GoogleFonts.outfit(
          color: const Color.fromRGBO(148, 163, 184, 0.65),
          fontSize: 6,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainterS.paint(
        canvas, Offset(center.dx - textPainterS.width / 2, center.dy + 38));

    final textPainterW = TextPainter(
      text: TextSpan(
        text: 'W',
        style: GoogleFonts.outfit(
          color: const Color.fromRGBO(148, 163, 184, 0.65),
          fontSize: 6,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainterW.paint(
        canvas, Offset(center.dx - 45, center.dy - textPainterW.height / 2));

    // 7. Location Pin Marker
    final pinPath = Path();
    pinPath.moveTo(center.dx, center.dy - 16);
    pinPath.cubicTo(center.dx - 12, center.dy - 16, center.dx - 12,
        center.dy - 6, center.dx - 12, center.dy - 4);
    pinPath.cubicTo(center.dx - 12, center.dy + 4, center.dx, center.dy + 16,
        center.dx, center.dy + 16);
    pinPath.cubicTo(center.dx, center.dy + 16, center.dx + 12, center.dy + 4,
        center.dx + 12, center.dy - 4);
    pinPath.cubicTo(center.dx + 12, center.dy - 6, center.dx + 12,
        center.dy - 16, center.dx, center.dy - 16);
    pinPath.close();

    final pinPaint = Paint()..color = const Color(0xFFF97316);
    canvas.drawPath(pinPath, pinPaint);

    final innerDotPaint = Paint()..color = const Color(0xFF080D1A);
    canvas.drawCircle(Offset(center.dx, center.dy - 4), 5, innerDotPaint);
  }

  void _drawDashedCircle(Canvas canvas, Offset center, double radius,
      double dashWidth, double dashSpace, Color color, double angleOffset) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    final circumference = 2 * math.pi * radius;
    final totalDashLength = dashWidth + dashSpace;
    final count = (circumference / totalDashLength).floor();

    for (int i = 0; i < count; i++) {
      final startAngle = angleOffset + (i * totalDashLength / radius);
      final sweepAngle = (dashWidth / radius);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CompassLogoPainter oldDelegate) {
    return oldDelegate.orbitAngle != orbitAngle;
  }
}

// ─── Bird Silhouette Painter ──────────────────────────────────────────────────
class _BirdPainter extends CustomPainter {
  final double opacity;

  _BirdPainter({required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Color.fromRGBO(249, 115, 22, opacity)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(6, 12);
    path.quadraticBezierTo(12, 5, 18, 12);
    path.moveTo(26, 10);
    path.quadraticBezierTo(32, 3, 38, 10);
    path.moveTo(44, 14);
    path.quadraticBezierTo(49, 7, 54, 14);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Particle Rise Widget ─────────────────────────────────────────────────────
class _RisingParticleWidget extends StatefulWidget {
  final _ParticleData particle;

  const _RisingParticleWidget({required this.particle});

  @override
  State<_RisingParticleWidget> createState() => _RisingParticleWidgetState();
}

class _RisingParticleWidgetState extends State<_RisingParticleWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(
          milliseconds: (widget.particle.durationSeconds * 1000).toInt()),
    );

    Future.delayed(
        Duration(milliseconds: (widget.particle.delaySeconds * 1000).toInt()),
        () {
      if (mounted) {
        _controller.repeat();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final val = _controller.value;
        final opacity = val < 0.15
            ? (val / 0.15)
            : val > 0.85
                ? ((1.0 - val) / 0.15)
                : 0.8;

        final dy = -160.0 * val;
        final dx = widget.particle.dx * val;

        return Transform.translate(
          offset: Offset(dx, dy),
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Container(
              width: widget.particle.size,
              height: widget.particle.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.particle.color,
                boxShadow: [
                  BoxShadow(
                    color: widget.particle.color.withValues(alpha: 0.8),
                    blurRadius: widget.particle.size * 4,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Sparkle Widget ───────────────────────────────────────────────────────────
class _SparkleWidget extends StatefulWidget {
  final _SparkleData sparkle;

  const _SparkleWidget({required this.sparkle});

  @override
  State<_SparkleWidget> createState() => _SparkleWidgetState();
}

class _SparkleWidgetState extends State<_SparkleWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(
          milliseconds: (widget.sparkle.durationSeconds * 1000).toInt()),
    );

    Future.delayed(
        Duration(milliseconds: (widget.sparkle.delaySeconds * 1000).toInt()),
        () {
      if (mounted) {
        _controller.repeat();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final val = _controller.value;
        final scale = (val >= 0.3 && val <= 0.7)
            ? (math.sin((val - 0.3) / 0.4 * math.pi))
            : 0.0;

        return Transform.scale(
          scale: scale,
          child: Container(
            width: widget.sparkle.size,
            height: widget.sparkle.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.sparkle.id % 2 == 0
                  ? const Color.fromRGBO(249, 115, 22, 0.9)
                  : const Color.fromRGBO(251, 191, 36, 0.85),
            ),
          ),
        );
      },
    );
  }
}
