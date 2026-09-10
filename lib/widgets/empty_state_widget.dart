import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_spacing.dart';
import '../core/constants/app_text_styles.dart';
import 'common_button.dart';

class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  });

  factory EmptyStateWidget.noContacts({VoidCallback? onAction}) {
    return EmptyStateWidget(
      icon: Icons.people_outline,
      title: 'No contacts yet',
      description: 'Your contacts will appear here once you connect with other users.',
      actionLabel: onAction != null ? 'Refresh' : null,
      onAction: onAction,
    );
  }

  factory EmptyStateWidget.noCalls({VoidCallback? onAction}) {
    return EmptyStateWidget(
      icon: Icons.phone_missed_outlined,
      title: 'No calls yet',
      description: 'Your recent audio and video call history will be saved here.',
      actionLabel: onAction != null ? 'Start a Call' : null,
      onAction: onAction,
    );
  }

  factory EmptyStateWidget.offline({VoidCallback? onRetry}) {
    return EmptyStateWidget(
      icon: Icons.wifi_off_rounded,
      title: "You're offline",
      description: 'Check your internet connection to place and receive calls.',
      actionLabel: onRetry != null ? 'Try Again' : null,
      onAction: onRetry,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: (isDark ? AppColors.darkElevatedSurface : AppColors.primarySoft)
                    .withValues(alpha: 0.8),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 38,
                color: isDark ? AppColors.primaryBlueLight : AppColors.primaryBlue,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              style: AppTextStyles.h3(
                color: isDark ? AppColors.darkPrimaryText : AppColors.primaryText,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              description,
              style: AppTextStyles.body(
                color: isDark ? AppColors.darkMutedText : AppColors.secondaryText,
              ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.xl),
              CommonButton(
                text: actionLabel!,
                onPressed: onAction,
                variant: ButtonVariant.secondary,
                width: 160,
                height: 44,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
