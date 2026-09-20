import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_radius.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../models/user_model.dart';
import '../../../widgets/status_badge.dart';
import '../../../widgets/user_avatar.dart';

class UserTile extends StatelessWidget {
  final UserModel user;
  final VoidCallback onAudioCall;
  final VoidCallback onVideoCall;
  final VoidCallback? onTap;
  final bool isCalling;

  const UserTile({
    super.key,
    required this.user,
    required this.onAudioCall,
    required this.onVideoCall,
    this.onTap,
    this.isCalling = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: AppRadius.roundedLg,
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.border,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.roundedLg,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.roundedLg,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Avatar with online indicator
                UserAvatar(
                  name: user.name,
                  photoUrl: user.photoUrl,
                  radius: 22,
                  isOnline: user.isOnline,
                  showBadge: true,
                ),

                const SizedBox(width: 14),

                // Name & Status
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        user.name,
                        style: AppTextStyles.title(
                          color: isDark ? AppColors.darkPrimaryText : AppColors.primaryText,
                        ).copyWith(fontSize: 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          user.isOnline ? StatusBadge.online() : StatusBadge.offline(),
                          if (!user.isOnline) ...[
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                user.lastSeenFormatted,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.caption(
                                  color: isDark ? AppColors.darkMutedText : AppColors.mutedText,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                if (isCalling)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryBlue),
                    ),
                  )
                else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Audio Call Action
                      IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkElevatedSurface : AppColors.primarySoft,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.phone_rounded,
                            color: isDark ? AppColors.primaryBlueLight : AppColors.primaryBlue,
                            size: 20,
                          ),
                        ),
                        tooltip: 'Audio Call ${user.name}',
                        onPressed: onAudioCall,
                      ),

                      // Video Call Action
                      IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkElevatedSurface : AppColors.cyanSoft,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.videocam_rounded,
                            color: isDark ? AppColors.cyan : AppColors.cyanDark,
                            size: 20,
                          ),
                        ),
                        tooltip: 'Video Call ${user.name}',
                        onPressed: onVideoCall,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
