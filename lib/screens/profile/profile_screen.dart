import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_radius.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/theme/theme_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common_button.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/user_avatar.dart';
import '../auth/login_screen.dart';
import 'edit_profile_dialog.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final themeMode = ref.watch(themeModeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        child: Column(
          children: [
            const SizedBox(height: 12),

            // Profile Picture & Online Status
            Center(
              child: Stack(
                children: [
                  UserAvatar(
                    name: user?.name ?? 'User',
                    photoUrl: user?.photoUrl,
                    radius: 54,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.primaryBlue,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.verified_user_rounded,
                        color: AppColors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // User Name
            Text(
              user?.name ?? 'ConnectCall User',
              style: AppTextStyles.h2(
                color: isDark ? AppColors.darkPrimaryText : AppColors.primaryText,
              ),
            ),

            const SizedBox(height: 4),

            // Email or Phone
            Text(
              user?.email ?? '',
              style: AppTextStyles.body(
                color: isDark ? AppColors.darkMutedText : AppColors.secondaryText,
              ),
            ),

            const SizedBox(height: 12),

            // Online Badge
            user?.isOnline == true ? StatusBadge.online() : StatusBadge.offline(),

            const SizedBox(height: AppSpacing.xxl),

            // Settings Card
            Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.surface,
                borderRadius: AppRadius.roundedLg,
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.border,
                ),
              ),
              child: Column(
                children: [
                  // Edit Profile Option
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkElevatedSurface : AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.edit_outlined, color: AppColors.primaryBlue, size: 20),
                    ),
                    title: Text(
                      'Edit Display Name',
                      style: AppTextStyles.bodyMedium(
                        color: isDark ? AppColors.darkPrimaryText : AppColors.primaryText,
                      ),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (_) => const EditProfileDialog(),
                      );
                    },
                  ),

                  Divider(
                    height: 1,
                    indent: 56,
                    color: isDark ? AppColors.darkBorder : AppColors.border,
                  ),

                  // Dark Mode Switch
                  SwitchListTile(
                    secondary: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkElevatedSurface : AppColors.cyanSoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                        color: AppColors.cyanDark,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      'Dark Theme',
                      style: AppTextStyles.bodyMedium(
                        color: isDark ? AppColors.darkPrimaryText : AppColors.primaryText,
                      ),
                    ),
                    value: themeMode == ThemeMode.dark,
                    onChanged: (val) {
                      ref.read(themeModeProvider.notifier).setThemeMode(
                            val ? ThemeMode.dark : ThemeMode.light,
                          );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),

            // Logout Button
            CommonButton(
              text: 'Log Out',
              variant: ButtonVariant.danger,
              icon: Icons.logout_rounded,
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Log Out'),
                    content: const Text('Are you sure you want to sign out of ConnectCall?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text('Log Out', style: TextStyle(color: AppColors.error)),
                      ),
                    ],
                  ),
                );

                if (confirm == true && context.mounted) {
                  await ref.read(authNotifierProvider.notifier).signOut();
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  }
                }
              },
            ),

            const SizedBox(height: AppSpacing.xxl),

            // Version info
            Text(
              'ConnectCall v1.0.0 (Production Build)',
              style: AppTextStyles.caption(
                color: isDark ? AppColors.darkMutedText : AppColors.mutedText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'WebRTC Real-Time Calling Engine',
              style: AppTextStyles.caption(color: AppColors.primaryBlue),
            ),
          ],
        ),
      ),
    );
  }
}
