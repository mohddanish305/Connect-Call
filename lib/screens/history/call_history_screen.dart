import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/call_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/call_history_provider.dart';
import '../../providers/call_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/user_avatar.dart';
import '../call/audio_call_screen.dart';
import '../call/video_call_screen.dart';

class CallHistoryScreen extends ConsumerWidget {
  const CallHistoryScreen({super.key});

  Future<void> _callBack(BuildContext context, WidgetRef ref, CallModel record) async {
    final userService = ref.read(userServiceProvider);
    final targetId = record.direction == CallDirection.outgoing ? record.calleeId : record.callerId;
    final targetName = record.direction == CallDirection.outgoing ? record.calleeName : record.callerName;
    final targetPhoto = record.direction == CallDirection.outgoing ? record.calleePhoto : record.callerPhoto;

    final targetUser = await userService.getUserById(targetId) ??
        UserModel(
          id: targetId,
          name: targetName,
          email: '$targetName@connectcall.io',
          photoUrl: targetPhoto,
          lastSeen: DateTime.now(),
        );

    final success = await ref.read(callControllerProvider.notifier).startCall(
          targetUser: targetUser,
          callType: record.callType,
        );

    if (success && context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => record.callType == CallType.video
              ? const VideoCallScreen()
              : const AudioCallScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(callHistoryNotifierProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Call History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 22),
            tooltip: 'Clear History',
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Clear Call History?'),
                  content: const Text('This will remove all recent call logs from this device.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        ref.read(callHistoryNotifierProvider.notifier).clearHistory();
                        Navigator.of(ctx).pop();
                      },
                      child: const Text('Clear', style: TextStyle(color: AppColors.error)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: historyAsync.when(
        data: (calls) {
          if (calls.isEmpty) {
            return EmptyStateWidget.noCalls();
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.read(callHistoryNotifierProvider.notifier).loadHistory();
            },
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: calls.length,
              separatorBuilder: (context, index) => Divider(
                height: 1,
                indent: 72,
                color: isDark ? AppColors.darkBorder : AppColors.border,
              ),
              itemBuilder: (context, index) {
                final call = calls[index];
                final currentUserId = ref.watch(currentUserProvider)?.id ?? '';
                final isOutgoing = call.callerId == currentUserId || call.direction == CallDirection.outgoing;

                final displayName = isOutgoing ? call.calleeName : call.callerName;
                final displayPhoto = isOutgoing ? call.calleePhoto : call.callerPhoto;

                IconData directionIcon;
                Color directionColor;

                if (call.isMissed) {
                  directionIcon = Icons.call_missed_rounded;
                  directionColor = AppColors.error;
                } else if (isOutgoing) {
                  directionIcon = Icons.call_made_rounded;
                  directionColor = isDark ? AppColors.primaryBlueLight : AppColors.primaryBlue;
                } else {
                  directionIcon = Icons.call_received_rounded;
                  directionColor = AppColors.success;
                }

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  leading: UserAvatar(
                    name: displayName,
                    photoUrl: displayPhoto,
                    radius: 24,
                  ),
                  title: Text(
                    displayName,
                    style: AppTextStyles.title(
                      color: call.isMissed
                          ? AppColors.error
                          : (isDark ? AppColors.darkPrimaryText : AppColors.primaryText),
                    ).copyWith(fontSize: 16),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(directionIcon, size: 16, color: directionColor),
                        const SizedBox(width: 6),
                        Text(
                          call.callType == CallType.video ? 'Video Call' : 'Audio Call',
                          style: AppTextStyles.caption(
                            color: isDark ? AppColors.darkMutedText : AppColors.secondaryText,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '•  ${DateFormatter.formatCallTime(call.startedAt)}',
                          style: AppTextStyles.caption(
                            color: isDark ? AppColors.darkMutedText : AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        call.isMissed
                            ? 'Missed'
                            : DateFormatter.formatDuration(call.duration),
                        style: AppTextStyles.caption(
                          color: call.isMissed
                              ? AppColors.error
                              : (isDark ? AppColors.darkMutedText : AppColors.secondaryText),
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(
                          call.callType == CallType.video
                              ? Icons.videocam_rounded
                              : Icons.phone_rounded,
                          color: isDark ? AppColors.primaryBlueLight : AppColors.primaryBlue,
                          size: 22,
                        ),
                        tooltip: 'Call Back',
                        onPressed: () => _callBack(context, ref, call),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primaryBlue),
        ),
        error: (e, _) => Center(
          child: Text('Failed to load call history: $e'),
        ),
      ),
    );
  }
}
