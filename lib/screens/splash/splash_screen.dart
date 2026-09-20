import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../providers/auth_provider.dart';
import '../auth/login_screen.dart';
import '../home/home_screen.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _animController;
  late AnimationController _waveController;

  late Animation<double> _bgOpacityAnimation;
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoOpacityAnimation;
  late Animation<double> _logoGlowAnimation;
  late Animation<Offset> _textSlideAnimation;
  late Animation<double> _textOpacityAnimation;

  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();

    // Primary splash intro animation controller (1500ms)
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Continuous wave & glow subtle float controller
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();

    // 1. Background fades in (0% - 30%)
    _bgOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.35, curve: Curves.easeIn),
      ),
    );

    // 2. App icon scales and fades in smoothly (20% - 65%)
    _logoScaleAnimation = Tween<double>(begin: 0.80, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.20, 0.65, curve: Curves.easeOutBack),
      ),
    );

    _logoOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.20, 0.55, curve: Curves.easeIn),
      ),
    );

    // 3. Subtle floating / glow effect on icon
    _logoGlowAnimation = Tween<double>(begin: 18.0, end: 32.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.40, 0.85, curve: Curves.easeOut),
      ),
    );

    // 4. "ConnectCall" text fades and slides in as a separate Flutter text layer (50% - 95%)
    _textSlideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.30),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.50, 0.95, curve: Curves.easeOutCubic),
      ),
    );

    _textOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.50, 0.90, curve: Curves.easeIn),
      ),
    );

    _animController.forward();
    _checkAuthAndNavigate();
  }

  /// Evaluates real startup state (onboarding completion & Firebase Auth state)
  /// and performs single, race-condition-free navigation.
  Future<void> _checkAuthAndNavigate() async {
    // 1. Minimum brand display duration to ensure smooth visual presentation
    await Future.delayed(const Duration(milliseconds: 1700));
    if (!mounted || _hasNavigated) return;

    // 2. Wait for Firebase Auth to resolve its persistent session.
    //    authStateChanges() emits null or User within ~1-2 seconds on startup.
    //    We poll the firebaseAuthStateProvider until it has a value (not loading).
    while (mounted && ref.read(firebaseAuthStateProvider).isLoading) {
      await Future.delayed(const Duration(milliseconds: 50));
    }
    if (!mounted || _hasNavigated) return;

    // 3. Also wait for AuthNotifier.init() to finish loading the UserModel.
    while (mounted && ref.read(authNotifierProvider).isLoading) {
      await Future.delayed(const Duration(milliseconds: 50));
    }
    if (!mounted || _hasNavigated) return;

    // 4. Use Firebase Auth as the single source of truth for authentication
    final User? firebaseUser = ref.read(firebaseAuthStateProvider).value;
    final isAuthenticated = firebaseUser != null;

    final Widget targetScreen = isAuthenticated ? const HomeScreen() : const LoginScreen();

    _hasNavigated = true;

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => targetScreen,
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient with Fade-In (IgnorePointer so it never intercepts hit tests)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _animController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _bgOpacityAnimation.value,
                    child: child,
                  );
                },
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: AppColors.splashGradient,
                  ),
                ),
              ),
            ),
          ),

          // Smooth flowing translucent wave shapes (visual background decoration)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _waveController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: SplashWavePainter(progress: _waveController.value),
                  );
                },
              ),
            ),
          ),

          // Centered Content: App Icon & Separate Flutter Text Layer
          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 3),

                  // Centered ConnectCall App Icon with Scale & Glow
                  AnimatedBuilder(
                    animation: Listenable.merge([_animController, _waveController]),
                    builder: (context, child) {
                      // Subtle breathing/floating oscillation
                      final floatOffset = math.sin(_waveController.value * 2 * math.pi) * 4.0;
                      return Opacity(
                        opacity: _logoOpacityAnimation.value,
                        child: Transform.translate(
                          offset: Offset(0, floatOffset),
                          child: Transform.scale(
                            scale: _logoScaleAnimation.value,
                            child: Container(
                              width: 112,
                              height: 112,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(28),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.cyan.withValues(alpha: 0.35),
                                    blurRadius: _logoGlowAnimation.value,
                                    spreadRadius: 2,
                                    offset: const Offset(0, 8),
                                  ),
                                  BoxShadow(
                                    color: AppColors.primaryBlueLight.withValues(alpha: 0.25),
                                    blurRadius: 48,
                                    spreadRadius: 6,
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(28),
                                child: Image.asset(
                                  'assets/images/logo.png',
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: AppColors.primaryBlueDark,
                                      child: const Icon(
                                        Icons.phone_in_talk_rounded,
                                        color: AppColors.white,
                                        size: 56,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 32),

                  // "ConnectCall" Flutter Text Layer (Fades and Slides In)
                  AnimatedBuilder(
                    animation: _animController,
                    builder: (context, child) {
                      return SlideTransition(
                        position: _textSlideAnimation,
                        child: Opacity(
                          opacity: _textOpacityAnimation.value,
                          child: child,
                        ),
                      );
                    },
                    child: Column(
                      children: [
                        RichText(
                          text: TextSpan(
                            style: AppTextStyles.display(color: AppColors.white).copyWith(
                              letterSpacing: -0.6,
                              fontWeight: FontWeight.w800,
                            ),
                            children: const [
                              TextSpan(text: 'Connect'),
                              TextSpan(
                                text: 'Call',
                                style: TextStyle(color: AppColors.cyan),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Connect with anyone, anywhere.',
                          style: AppTextStyles.bodyMedium(
                            color: AppColors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(flex: 4),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter rendering smooth flowing translucent wave shapes in the background
class SplashWavePainter extends CustomPainter {
  final double progress;

  SplashWavePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Wave 1: Gentle cyan wave flowing across lower third
    final wave1Paint = Paint()
      ..color = AppColors.cyan.withValues(alpha: 0.09)
      ..style = PaintingStyle.fill;

    final path1 = Path();
    final yOffset1 = h * 0.72;
    path1.moveTo(0, yOffset1);

    final shift1 = progress * 2 * math.pi;
    for (double x = 0; x <= w; x += 10) {
      final y = yOffset1 + math.sin((x / w * 2 * math.pi) + shift1) * 22;
      path1.lineTo(x, y);
    }
    path1.lineTo(w, h);
    path1.lineTo(0, h);
    path1.close();
    canvas.drawPath(path1, wave1Paint);

    // Wave 2: Deep blue translucent crest in opposite phase
    final wave2Paint = Paint()
      ..color = AppColors.primaryBlueLight.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;

    final path2 = Path();
    final yOffset2 = h * 0.78;
    path2.moveTo(0, yOffset2);

    final shift2 = -progress * 2 * math.pi;
    for (double x = 0; x <= w; x += 10) {
      final y = yOffset2 + math.cos((x / w * 2 * math.pi) + shift2) * 26;
      path2.lineTo(x, y);
    }
    path2.lineTo(w, h);
    path2.lineTo(0, h);
    path2.close();
    canvas.drawPath(path2, wave2Paint);

    // Wave 3: Subtle top ambient wave
    final wave3Paint = Paint()
      ..color = AppColors.cyan.withValues(alpha: 0.05)
      ..style = PaintingStyle.fill;

    final path3 = Path();
    path3.moveTo(0, 0);
    path3.lineTo(w, 0);
    final yOffset3 = h * 0.14;
    for (double x = w; x >= 0; x -= 10) {
      final y = yOffset3 + math.sin((x / w * 2 * math.pi) + shift1 * 0.7) * 16;
      path3.lineTo(x, y);
    }
    path3.close();
    canvas.drawPath(path3, wave3Paint);
  }

  @override
  bool shouldRepaint(covariant SplashWavePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
