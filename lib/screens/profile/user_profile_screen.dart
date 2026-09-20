import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_radius.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/call_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/block_provider.dart';
import '../../providers/call_provider.dart';
import '../../widgets/user_avatar.dart';
import '../call/audio_call_screen.dart';
import '../call/video_call_screen.dart';

class UserProfileScreen extends ConsumerStatefulWidget {
  final UserModel user;

  const UserProfileScreen({
    super.key,
    required this.user,
  });

  static Future<void> show(BuildContext context, UserModel user) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UserProfileScreen(user: user),
    );
  }

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen> {
  bool _isProcessing = false;
  String? _callingUserId;

  Future<void> _startCall(CallType callType) async {
    final targetUser = widget.user;
    final currentUser = ref.read(currentUserProvider);
    if (currentUser != null && targetUser.id == currentUser.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You cannot call yourself.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final isBlocked = ref.read(isUserBlockedProvider(targetUser.id));
    if (isBlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You have blocked this user.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_callingUserId != null) return;
    setState(() => _callingUserId = targetUser.id);

    try {
      final success = await ref.read(callControllerProvider.notifier).startCall(
            targetUser: targetUser,
            callType: callType,
          );

      if (success && mounted) {
        Navigator.of(context).pop(); // Close bottom sheet
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => callType == CallType.video
                ? const VideoCallScreen()
                : const AudioCallScreen(),
          ),
        );
      } else if (mounted) {
        final session = ref.read(callControllerProvider);
        if (session.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(session.errorMessage!),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _callingUserId = null);
      }
    }
  }

  Future<void> _handleBlockToggle(bool isCurrentlyBlocked) async {
    final targetUser = widget.user;
    final blockService = ref.read(blockServiceProvider);

    if (isCurrentlyBlocked) {
      // Unblock User
      setState(() => _isProcessing = true);
      try {
        await blockService.unblockUser(targetUser.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User unblocked'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to unblock: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isProcessing = false);
        }
      }
    } else {
      // Show confirmation dialog before blocking
      final confirm = await showDialog<bool>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          title: const Text('Block User?'),
          content: const Text('You will no longer be able to call this user.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text(
                'Block',
                style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );

      if (confirm == true && mounted) {
        setState(() => _isProcessing = true);
        try {
          await blockService.blockUser(
            targetUser.id,
            targetName: targetUser.name,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('User blocked'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to block: $e'),
                backgroundColor: AppColors.error,
              ),
            );
          }
        } finally {
          if (mounted) {
            setState(() => _isProcessing = false);
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isBlocked = ref.watch(isUserBlockedProvider(user.id));

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 16,
        bottom: MediaQuery.of(context).viewPadding.bottom + 20,
        left: 24,
        right: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Avatar with online status
          UserAvatar(
            name: user.name,
            photoUrl: user.photoUrl,
            radius: 40,
            isOnline: user.isOnline,
            showBadge: true,
          ),
          const SizedBox(height: 14),

          // User Name
          Text(
            user.name,
            style: AppTextStyles.h2(
              color: isDark ? AppColors.darkPrimaryText : AppColors.primaryText,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),

          // Email / Phone
          if (user.email.isNotEmpty)
            Text(
              user.email,
              style: AppTextStyles.body(
                color: isDark ? AppColors.darkMutedText : AppColors.secondaryText,
              ),
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 6),

          // Last seen or blocked indicator
          if (isBlocked)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.12),
                borderRadius: AppRadius.roundedFull,
              ),
              child: const Text(
                'Blocked',
                style: TextStyle(
                  color: AppColors.error,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            Text(
              user.lastSeenFormatted,
              style: AppTextStyles.caption(
                color: user.isOnline ? AppColors.success : AppColors.mutedText,
              ),
            ),

          const SizedBox(height: 24),

          // Call Buttons Row
          Row(
            children: [
              // Audio Call Button
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isBlocked ? Colors.grey.shade400 : AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.phone_rounded, size: 20),
                  label: const Text('Audio Call', style: TextStyle(fontWeight: FontWeight.w600)),
                  onPressed: isBlocked ? null : () => _startCall(CallType.audio),
                ),
              ),
              const SizedBox(width: 12),
              // Video Call Button
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isBlocked ? Colors.grey.shade400 : AppColors.cyan,
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.videocam_rounded, size: 22),
                  label: const Text('Video Call', style: TextStyle(fontWeight: FontWeight.w600)),
                  onPressed: isBlocked ? null : () => _startCall(CallType.video),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),

          // Block / Unblock Action Button
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            tileColor: isBlocked
                ? AppColors.primaryBlue.withValues(alpha: 0.08)
                : AppColors.error.withValues(alpha: 0.08),
            leading: _isProcessing
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    isBlocked ? Icons.lock_open_rounded : Icons.block_rounded,
                    color: isBlocked ? AppColors.primaryBlue : AppColors.error,
                  ),
            title: Text(
              isBlocked ? 'Unblock User' : 'Block User',
              style: TextStyle(
                color: isBlocked ? AppColors.primaryBlue : AppColors.error,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              isBlocked
                ? 'Allow calls and restore to contacts'
                : 'You will no longer be able to call this user.',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.darkMutedText : AppColors.secondaryText,
              ),
            ),
            onTap: _isProcessing ? null : () => _handleBlockToggle(isBlocked),
          ),
        ],
      ),
    );
  }
}
