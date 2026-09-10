import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common_button.dart';
import '../home/home_screen.dart';
import 'register_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailPhoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailPhoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref.read(authNotifierProvider.notifier).signIn(
          emailOrPhone: _emailPhoneController.text,
          password: _passwordController.text,
        );

    if (success && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  void _quickFill(String email, String password) {
    _emailPhoneController.text = email;
    _passwordController.text = password;
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: AppSpacing.lg),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo Mark & Title
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: AppColors.primaryGradient,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset(
                            'assets/images/logo.png',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.phone_in_talk_rounded,
                              color: AppColors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      RichText(
                        text: TextSpan(
                          text: 'Connect',
                          style: AppTextStyles.h3(
                            color: isDark ? AppColors.darkPrimaryText : AppColors.primaryText,
                          ),
                          children: const [
                            TextSpan(
                              text: 'Call',
                              style: TextStyle(color: AppColors.primaryBlue),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.xxxl),

                  Text(
                    'Welcome back',
                    style: AppTextStyles.h1(
                      color: isDark ? AppColors.darkPrimaryText : AppColors.primaryText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Sign in to start crystal clear audio and video calls.',
                    style: AppTextStyles.body(
                      color: isDark ? AppColors.darkMutedText : AppColors.secondaryText,
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xxl),

                  // Error Banner
                  if (authState.error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              authState.error!,
                              style: AppTextStyles.caption(color: AppColors.error),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],

                  // Email or Phone Field
                  Text(
                    'Email or Phone',
                    style: AppTextStyles.bodyMedium(
                      color: isDark ? AppColors.darkPrimaryText : AppColors.primaryText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _emailPhoneController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      hintText: 'e.g. sarah.johnson@connectcall.io',
                      prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Please enter your email or phone';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // Password Field
                  Text(
                    'Password',
                    style: AppTextStyles.bodyMedium(
                      color: isDark ? AppColors.darkPrimaryText : AppColors.primaryText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      hintText: 'Enter your password',
                      prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.isEmpty) {
                        return 'Please enter your password';
                      }
                      if (val.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: AppSpacing.xxl),

                  // Login Button
                  CommonButton(
                    text: 'Sign In',
                    isLoading: authState.isLoading,
                    onPressed: _handleLogin,
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // Create Account Navigation
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account? ",
                          style: AppTextStyles.body(
                            color: isDark ? AppColors.darkMutedText : AppColors.secondaryText,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const RegisterScreen()),
                            );
                          },
                          child: Text(
                            'Create Account',
                            style: AppTextStyles.button(color: AppColors.primaryBlue),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xxxl),

                  // Quick Demo Accounts for fast testing
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkElevatedSurface : AppColors.surfaceSecondary,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.border,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quick Demo Accounts (1-Tap Fill):',
                          style: AppTextStyles.caption(
                            color: isDark ? AppColors.darkMutedText : AppColors.secondaryText,
                          ).copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            ActionChip(
                              avatar: const CircleAvatar(
                                radius: 10,
                                backgroundColor: AppColors.primaryBlue,
                                child: Text('S', style: TextStyle(fontSize: 10, color: Colors.white)),
                              ),
                              label: const Text('Sarah Johnson'),
                              onPressed: () => _quickFill('sarah.johnson@connectcall.io', 'password123'),
                            ),
                            ActionChip(
                              avatar: const CircleAvatar(
                                radius: 10,
                                backgroundColor: AppColors.cyanDark,
                                child: Text('J', style: TextStyle(fontSize: 10, color: Colors.white)),
                              ),
                              label: const Text('John Smith'),
                              onPressed: () => _quickFill('john.smith@connectcall.io', 'password123'),
                            ),
                            ActionChip(
                              avatar: const CircleAvatar(
                                radius: 10,
                                backgroundColor: AppColors.primaryBlueLight,
                                child: Text('A', style: TextStyle(fontSize: 10, color: Colors.white)),
                              ),
                              label: const Text('Alex Wilson'),
                              onPressed: () => _quickFill('alex.wilson@connectcall.io', 'password123'),
                            ),
                          ],
                        ),
                      ],
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
