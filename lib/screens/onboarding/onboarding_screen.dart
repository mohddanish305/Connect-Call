import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_radius.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../providers/onboarding_provider.dart';
import '../auth/login_screen.dart';
import 'widgets/onboarding_illustrations.dart';

class OnboardingItem {
  final String title;
  final String description;
  final Widget illustration;

  const OnboardingItem({
    required this.title,
    required this.description,
    required this.illustration,
  });
}

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingItem> _pages = const [
    OnboardingItem(
      title: 'Connect with anyone',
      description: 'Find your people and stay connected wherever you are.',
      illustration: OnboardingIllustration1(),
    ),
    OnboardingItem(
      title: 'Crystal-clear calling',
      description: 'Make seamless audio and video calls with the people who matter.',
      illustration: OnboardingIllustration2(),
    ),
    OnboardingItem(
      title: 'Always stay connected',
      description: 'Call, chat and keep track of your conversations in one simple place.',
      illustration: OnboardingIllustration3(),
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    final onboardingService = ref.read(onboardingServiceProvider);
    await onboardingService.completeOnboarding();

    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const LoginScreen(),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 350),
        ),
      );
    }
  }

  void _onNextPressed() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _completeOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLastPage = _currentPage == _pages.length - 1;

    return PopScope(
      canPop: _currentPage == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _currentPage > 0) {
          _pageController.previousPage(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        body: SafeArea(
          child: Column(
            children: [
              // Top Bar with Skip Button
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xxl,
                  vertical: AppSpacing.sm,
                ),
                child: SizedBox(
                  height: 44,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Subtle Logo Mark
                      Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              gradient: AppColors.primaryGradient,
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.phone_in_talk_rounded,
                                color: AppColors.white,
                                size: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'ConnectCall',
                            style: AppTextStyles.button(
                              color: isDark ? AppColors.darkPrimaryText : AppColors.primaryText,
                            ).copyWith(fontSize: 15),
                          ),
                        ],
                      ),

                      // Skip Button
                      TextButton(
                        onPressed: _completeOnboarding,
                        style: TextButton.styleFrom(
                          minimumSize: const Size(44, 44),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: Text(
                          'Skip',
                          style: AppTextStyles.bodyMedium(
                            color: isDark ? AppColors.darkMutedText : AppColors.secondaryText,
                          ).copyWith(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Page Content (Illustration ~48%, Text ~25%)
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _pages.length,
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                  },
                  itemBuilder: (context, index) {
                    final page = _pages[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Illustration Area
                          Expanded(
                            flex: 5,
                            child: Center(
                              child: page.illustration,
                            ),
                          ),

                          // Text Content Area
                          Expanded(
                            flex: 3,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
                                  transitionBuilder: (child, anim) => FadeTransition(
                                    opacity: anim,
                                    child: SlideTransition(
                                      position: Tween<Offset>(
                                        begin: const Offset(0.0, 0.15),
                                        end: Offset.zero,
                                      ).animate(anim),
                                      child: child,
                                    ),
                                  ),
                                  child: Text(
                                    page.title,
                                    key: ValueKey(page.title),
                                    style: AppTextStyles.h1(
                                      color: isDark ? AppColors.darkPrimaryText : AppColors.primaryText,
                                    ).copyWith(fontSize: 28),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
                                  transitionBuilder: (child, anim) => FadeTransition(
                                    opacity: anim,
                                    child: SlideTransition(
                                      position: Tween<Offset>(
                                        begin: const Offset(0.0, 0.12),
                                        end: Offset.zero,
                                      ).animate(anim),
                                      child: child,
                                    ),
                                  ),
                                  child: Text(
                                    page.description,
                                    key: ValueKey(page.description),
                                    style: AppTextStyles.body(
                                      color: isDark ? AppColors.darkMutedText : AppColors.secondaryText,
                                    ).copyWith(fontSize: 15, height: 1.45),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Bottom Section: Pagination Indicators + Next / Get Started Button
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xxl,
                  vertical: AppSpacing.lg,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Pagination Indicators
                    Row(
                      children: List.generate(
                        _pages.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOut,
                          margin: const EdgeInsets.only(right: 6),
                          width: _currentPage == index ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _currentPage == index
                                ? AppColors.primaryBlue
                                : (isDark ? AppColors.darkBorder : const Color(0xFFCBD5E1)),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),

                    // Next / Get Started Action Button
                    ElevatedButton(
                      onPressed: _onNextPressed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: AppColors.white,
                        minimumSize: const Size(120, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.roundedLg,
                        ),
                        elevation: 2,
                        shadowColor: AppColors.primaryBlue.withValues(alpha: 0.3),
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Text(
                          isLastPage ? 'Get Started' : 'Next',
                          key: ValueKey(isLastPage),
                          style: AppTextStyles.button(color: AppColors.white).copyWith(fontSize: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
