import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_radius.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/theme/theme_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/call_history_provider.dart';
import '../../providers/call_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/common_button.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/user_avatar.dart';
import '../auth/login_screen.dart';
import 'blocked_users_screen.dart';
import 'edit_profile_dialog.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  void _showThemeDialog(BuildContext context, WidgetRef ref, ThemeMode currentMode) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Select App Theme'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('System default'),
                trailing: currentMode == ThemeMode.system
                    ? const Icon(Icons.check_rounded, color: AppColors.primaryBlue)
                    : null,
                onTap: () {
                  ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.system);
                  Navigator.of(ctx).pop();
                },
              ),
              ListTile(
                title: const Text('Light'),
                trailing: currentMode == ThemeMode.light
                    ? const Icon(Icons.check_rounded, color: AppColors.primaryBlue)
                    : null,
                onTap: () {
                  ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.light);
                  Navigator.of(ctx).pop();
                },
              ),
              ListTile(
                title: const Text('Dark'),
                trailing: currentMode == ThemeMode.dark
                    ? const Icon(Icons.check_rounded, color: AppColors.primaryBlue)
                    : null,
                onTap: () {
                  ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.dark);
                  Navigator.of(ctx).pop();
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

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

            // Profile Picture & Verified Badge
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
              user?.email.isNotEmpty == true ? user!.email : (user?.phone ?? ''),
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

                  // Theme Mode Option (System default, Light, Dark)
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkElevatedSurface : AppColors.cyanSoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        themeMode == ThemeMode.dark
                            ? Icons.dark_mode_rounded
                            : (themeMode == ThemeMode.light
                                ? Icons.light_mode_rounded
                                : Icons.brightness_auto_rounded),
                        color: AppColors.cyanDark,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      'App Theme',
                      style: AppTextStyles.bodyMedium(
                        color: isDark ? AppColors.darkPrimaryText : AppColors.primaryText,
                      ),
                    ),
                    subtitle: Text(
                      themeMode == ThemeMode.dark
                          ? 'Dark'
                          : (themeMode == ThemeMode.light ? 'Light' : 'System default'),
                      style: AppTextStyles.caption(
                        color: isDark ? AppColors.darkMutedText : AppColors.secondaryText,
                      ),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                    onTap: () => _showThemeDialog(context, ref, themeMode),
                  ),

                  Divider(
                    height: 1,
                    indent: 56,
                    color: isDark ? AppColors.darkBorder : AppColors.border,
                  ),

                  // Blocked Users Management
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkElevatedSurface : Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.block_rounded,
                        color: AppColors.error,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      'Blocked Users',
                      style: AppTextStyles.bodyMedium(
                        color: isDark ? AppColors.darkPrimaryText : AppColors.primaryText,
                      ),
                    ),
                    subtitle: Text(
                      'Manage and unblock users',
                      style: AppTextStyles.caption(
                        color: isDark ? AppColors.darkMutedText : AppColors.secondaryText,
                      ),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const BlockedUsersScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),

            // Sign Out Button with Section 5 Confirmation Dialog
            CommonButton(
              text: 'Sign Out',
              variant: ButtonVariant.danger,
              icon: Icons.logout_rounded,
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Sign out?'),
                    content: const Text('Are you sure you want to sign out?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text('Sign out', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );

                if (confirm == true && context.mounted) {
                  // 1. Ensure no active call exists & clean up call resources
                  await ref.read(callControllerProvider.notifier).endCall();
                  ref.read(callControllerProvider.notifier).resetSession();

                  // 2. Sign out from Firebase Auth and local session
                  await ref.read(authNotifierProvider.notifier).signOut();

                  // 3. Clear user-specific providers
                  ref.invalidate(contactsStreamProvider);
                  ref.invalidate(contactsListProvider);
                  ref.invalidate(callHistoryNotifierProvider);

                  // 4. Navigate to Login and clear route stack
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
              'Agora RTC Real-Time Calling Engine',
              style: AppTextStyles.caption(color: AppColors.primaryBlue),
            ),
          ],
        ),
      ),
    );
  }
}
