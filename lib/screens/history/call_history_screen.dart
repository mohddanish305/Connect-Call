import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/models/call_history_model.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/user_model.dart';
import '../../providers/call_history_provider.dart';
import '../../providers/call_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/user_avatar.dart';
import '../call/audio_call_screen.dart';

class CallHistoryScreen extends ConsumerWidget {
  const CallHistoryScreen({super.key});

  Future<void> _callBack(BuildContext context, WidgetRef ref, CallHistoryModel record) async {
    final userService = ref.read(userServiceProvider);
    final targetId = record.otherUserId;
    final targetName = record.otherUserName;
    final targetPhoto = record.otherUserAvatar;

    final targetUser = await userService.getUserById(targetId) ??
        UserModel(
          id: targetId,
          name: targetName,
          email: '$targetName@connectcall.io',
          photoUrl: targetPhoto,
          lastSeen: DateTime.now(),
        );

    final success = await ref.read(callControllerProvider.notifier).startAudioCall(
          targetUser: targetUser,
        );

    if (success && context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const AudioCallScreen(),
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
                  content: const Text('This will remove all recent call logs for your account.'),
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
            return const Center(
              child: EmptyStateWidget(
                icon: Icons.phone_outlined,
                title: 'No calls yet',
                description: 'Your recent calls will appear here.',
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              await ref.read(callHistoryNotifierProvider.notifier).loadHistory();
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
                final isOutgoing = call.direction == CallDirection.outgoing;
                final isMissed = call.status == CallHistoryStatus.missed;
                final isRejected = call.status == CallHistoryStatus.rejected;
                final isFailed = call.status == CallHistoryStatus.failed;

                IconData directionIcon;
                Color directionColor;

                if (isMissed) {
                  directionIcon = Icons.call_missed_rounded;
                  directionColor = AppColors.error;
                } else if (isRejected) {
                  directionIcon = Icons.phone_disabled_rounded;
                  directionColor = AppColors.error;
                } else if (isFailed) {
                  directionIcon = Icons.error_outline_rounded;
                  directionColor = isDark ? AppColors.darkMutedText : AppColors.secondaryText;
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
                    name: call.otherUserName,
                    photoUrl: call.otherUserAvatar,
                    radius: 24,
                  ),
                  title: Text(
                    call.otherUserName,
                    style: AppTextStyles.title(
                      color: (isMissed || isRejected)
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
                          call.callType == CallType.video ? 'Video' : 'Audio',
                          style: AppTextStyles.caption(
                            color: isDark ? AppColors.darkMutedText : AppColors.secondaryText,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text('•'),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            DateFormatter.formatCallTime(call.endedAt),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption(
                              color: isDark ? AppColors.darkMutedText : AppColors.secondaryText,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        call.formattedDurationOrStatus,
                        style: AppTextStyles.caption(
                          color: (isMissed || isRejected)
                              ? AppColors.error
                              : (isDark ? AppColors.darkMutedText : AppColors.secondaryText),
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(
                          Icons.phone_rounded,
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
        loading: () => Center(
          child: CircularProgressIndicator(
            color: isDark ? AppColors.primaryBlueLight : AppColors.primaryBlue,
          ),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
                const SizedBox(height: 16),
                Text(
                  'Unable to load call history.',
                  style: AppTextStyles.h3(
                    color: isDark ? AppColors.darkPrimaryText : AppColors.primaryText,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Please check your network connection.',
                  style: AppTextStyles.caption(
                    color: isDark ? AppColors.darkMutedText : AppColors.secondaryText,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    ref.read(callHistoryNotifierProvider.notifier).loadHistory();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
