import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_radius.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/call_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/call_history_provider.dart';
import '../../providers/call_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/user_avatar.dart';
import '../call/audio_call_screen.dart';
import '../call/video_call_screen.dart';

class HomeDashboardTab extends ConsumerWidget {
  final VoidCallback onNavigateToContacts;
  final VoidCallback onNavigateToCalls;

  const HomeDashboardTab({
    super.key,
    required this.onNavigateToContacts,
    required this.onNavigateToCalls,
  });

  Future<void> _startCall(BuildContext context, WidgetRef ref, UserModel targetUser, CallType callType) async {
    final success = await ref.read(callControllerProvider.notifier).startCall(
          targetUser: targetUser,
          callType: callType,
        );

    if (success && context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => callType == CallType.video
              ? const VideoCallScreen()
              : const AudioCallScreen(),
        ),
      );
    }
  }

  void _simulateIncomingCall(BuildContext context, WidgetRef ref) {
    final contactsAsync = ref.read(contactsListProvider);
    contactsAsync.whenData((contacts) {
      if (contacts.isNotEmpty) {
        final caller = contacts.first;
        ref.read(callControllerProvider.notifier).triggerIncomingCallDemo(
              caller: caller,
              callType: CallType.video,
            );
      }
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    final contactsAsync = ref.watch(contactsListProvider);
    final historyAsync = ref.watch(callHistoryNotifierProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Profile Greeting
              Row(
                children: [
                  UserAvatar(
                    name: currentUser?.name ?? 'User',
                    photoUrl: currentUser?.photoUrl,
                    radius: 26,
                    isOnline: true,
                    showBadge: true,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hello, ${currentUser?.name.split(' ').first ?? 'there'} 👋',
                          style: AppTextStyles.h3(
                            color: isDark ? AppColors.darkPrimaryText : AppColors.primaryText,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Ready to connect?',
                          style: AppTextStyles.caption(
                            color: isDark ? AppColors.darkMutedText : AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Demo Incoming Call Trigger (for easy 1-device review)
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkElevatedSurface : AppColors.cyanSoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.ring_volume_rounded, color: AppColors.cyanDark, size: 20),
                    ),
                    tooltip: 'Test Incoming Call',
                    onPressed: () => _simulateIncomingCall(context, ref),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.xl),

              // Search Trigger Banner
              GestureDetector(
                onTap: onNavigateToContacts,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkElevatedSurface : AppColors.surfaceSecondary,
                    borderRadius: AppRadius.roundedLg,
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search_rounded,
                        color: isDark ? AppColors.darkMutedText : AppColors.secondaryText,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Search people to call...',
                        style: AppTextStyles.body(
                          color: isDark ? AppColors.darkMutedText : AppColors.mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.xxl),

              // Quick Actions / Calling Feature Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: AppRadius.roundedLg,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryBlue.withValues(alpha: 0.3),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.wifi_calling_3_rounded, color: AppColors.white, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'WebRTC High Definition Calling',
                          style: AppTextStyles.caption(color: AppColors.white).copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Connect with anyone, anywhere.',
                      style: AppTextStyles.h3(color: AppColors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Crystal clear 1-to-1 audio and video calling powered by WebRTC.',
                      style: AppTextStyles.body(color: AppColors.white.withValues(alpha: 0.85)),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xxl),

              // "Online Contacts" Horizontal Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Online Now',
                    style: AppTextStyles.title(
                      color: isDark ? AppColors.darkPrimaryText : AppColors.primaryText,
                    ),
                  ),
                  TextButton(
                    onPressed: onNavigateToContacts,
                    child: Text(
                      'See All',
                      style: AppTextStyles.caption(color: AppColors.primaryBlue)
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              contactsAsync.when(
                data: (contacts) {
                  final onlineContacts = contacts.where((u) => u.isOnline).toList();
                  if (onlineContacts.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'No contacts currently online',
                        style: AppTextStyles.caption(
                          color: isDark ? AppColors.darkMutedText : AppColors.secondaryText,
                        ),
                      ),
                    );
                  }

                  return SizedBox(
                    height: 104,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: onlineContacts.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 16),
                      itemBuilder: (context, index) {
                        final user = onlineContacts[index];
                        return GestureDetector(
                          onTap: () => _startCall(context, ref, user, CallType.audio),
                          child: Column(
                            children: [
                              UserAvatar(
                                name: user.name,
                                photoUrl: user.photoUrl,
                                radius: 28,
                                isOnline: true,
                                showBadge: true,
                              ),
                              const SizedBox(height: 6),
                              SizedBox(
                                width: 70,
                                child: Text(
                                  user.name.split(' ').first,
                                  style: AppTextStyles.caption(
                                    color: isDark ? AppColors.darkPrimaryText : AppColors.primaryText,
                                  ).copyWith(fontWeight: FontWeight.w500),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                },
                loading: () => const SizedBox(height: 80, child: Center(child: CircularProgressIndicator())),
                error: (_, __) => const SizedBox.shrink(),
              ),

              const SizedBox(height: AppSpacing.lg),

              // "Recent Calls" Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Calls',
                    style: AppTextStyles.title(
                      color: isDark ? AppColors.darkPrimaryText : AppColors.primaryText,
                    ),
                  ),
                  TextButton(
                    onPressed: onNavigateToCalls,
                    child: Text(
                      'View All',
                      style: AppTextStyles.caption(color: AppColors.primaryBlue)
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              historyAsync.when(
                data: (calls) {
                  final recentCalls = calls.take(3).toList();
                  if (recentCalls.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : AppColors.surface,
                        borderRadius: AppRadius.roundedLg,
                        border: Border.all(
                          color: isDark ? AppColors.darkBorder : AppColors.border,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'No recent calls yet. Tap Contacts to start one!',
                          style: AppTextStyles.body(
                            color: isDark ? AppColors.darkMutedText : AppColors.secondaryText,
                          ),
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: recentCalls.map((call) {
                      final currentUserId = currentUser?.id ?? '';
                      final isOutgoing = call.callerId == currentUserId || call.direction == CallDirection.outgoing;
                      final displayName = isOutgoing ? call.calleeName : call.callerName;
                      final displayPhoto = isOutgoing ? call.calleePhoto : call.callerPhoto;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurface : AppColors.surface,
                          borderRadius: AppRadius.roundedLg,
                          border: Border.all(
                            color: isDark ? AppColors.darkBorder : AppColors.border,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          leading: UserAvatar(
                            name: displayName,
                            photoUrl: displayPhoto,
                            radius: 20,
                          ),
                          title: Text(
                            displayName,
                            style: AppTextStyles.title(
                              color: call.isMissed
                                  ? AppColors.error
                                  : (isDark ? AppColors.darkPrimaryText : AppColors.primaryText),
                            ).copyWith(fontSize: 15),
                          ),
                          subtitle: Text(
                            '${call.callType == CallType.video ? 'Video Call' : 'Audio Call'} • ${DateFormatter.formatCallTime(call.startedAt)}',
                            style: AppTextStyles.caption(
                              color: isDark ? AppColors.darkMutedText : AppColors.secondaryText,
                            ),
                          ),
                          trailing: IconButton(
                            icon: Icon(
                              call.callType == CallType.video ? Icons.videocam_rounded : Icons.phone_rounded,
                              color: isDark ? AppColors.primaryBlueLight : AppColors.primaryBlue,
                              size: 20,
                            ),
                            onPressed: () {
                              final targetUser = UserModel(
                                id: isOutgoing ? call.calleeId : call.callerId,
                                name: displayName,
                                email: '$displayName@connectcall.io',
                                photoUrl: displayPhoto,
                                lastSeen: DateTime.now(),
                              );
                              _startCall(context, ref, targetUser, call.callType);
                            },
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
