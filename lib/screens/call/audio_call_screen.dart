import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/call_model.dart';
import '../../providers/call_provider.dart';
import '../../widgets/call_action_button.dart';
import '../../widgets/user_avatar.dart';

class AudioCallScreen extends ConsumerStatefulWidget {
  const AudioCallScreen({super.key});

  @override
  ConsumerState<AudioCallScreen> createState() => _AudioCallScreenState();
}

class _AudioCallScreenState extends ConsumerState<AudioCallScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String _getStatusText(CallStatus status) {
    switch (status) {
      case CallStatus.calling:
        return 'Calling...';
      case CallStatus.ringing:
        return 'Ringing...';
      case CallStatus.connected:
        return 'Connecting...';
      case CallStatus.inCall:
        return 'Connected';
      case CallStatus.ended:
        return 'Call Ended';
      case CallStatus.rejected:
        return 'Call Declined';
      case CallStatus.missed:
        return 'Missed Call';
      case CallStatus.busy:
        return 'User Busy';
      case CallStatus.failed:
        return 'Call Failed';
      case CallStatus.disconnected:
        return 'Disconnected';
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(callControllerProvider);
    final call = session.call;

    // Listen for ended or rejected state to auto-close screen
    ref.listen(callControllerProvider, (previous, next) {
      if (next.status == CallStatus.ended ||
          next.status == CallStatus.rejected ||
          next.status == CallStatus.failed) {
        final nav = Navigator.of(context);
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted && nav.canPop()) {
            nav.pop();
          }
        });
      }
    });

    final isCallActive = session.status == CallStatus.inCall;
    final otherPartyName = call?.calleeName ?? 'Unknown';
    final otherPartyPhoto = call?.calleePhoto;

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppColors.callGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down_rounded,
                          color: AppColors.white, size: 28),
                      onPressed: () {
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        }
                      },
                    ),
                    Row(
                      children: [
                        const Icon(Icons.lock_outline_rounded,
                            color: AppColors.cyan, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          'End-to-end encrypted',
                          style: AppTextStyles.caption(color: AppColors.darkMutedText),
                        ),
                      ],
                    ),
                    const SizedBox(width: 48), // Balance spacing
                  ],
                ),
              ),

              const Spacer(flex: 1),

              // Caller Name
              Text(
                otherPartyName,
                style: AppTextStyles.h1(color: AppColors.darkPrimaryText),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              // Call Duration or Status
              if (isCallActive)
                Text(
                  DateFormatter.formatDuration(session.durationSeconds),
                  style: AppTextStyles.callDuration(color: AppColors.cyan),
                )
              else
                Text(
                  _getStatusText(session.status),
                  style: AppTextStyles.title(color: AppColors.darkMutedText),
                ),

              const SizedBox(height: AppSpacing.xxxl),

              // Pulsing Avatar
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryBlueLight.withValues(alpha: 0.25),
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: UserAvatar(
                    name: otherPartyName,
                    photoUrl: otherPartyPhoto,
                    radius: 70,
                  ),
                ),
              ),

              if (session.errorMessage != null) ...[
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    session.errorMessage!,
                    style: AppTextStyles.body(color: AppColors.error),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],

              const Spacer(flex: 2),

              // Controls Bar: Mute | Speaker | End
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Mute Button
                    CallActionButton(
                      icon: session.isMuted
                          ? Icons.mic_off_rounded
                          : Icons.mic_rounded,
                      label: session.isMuted ? 'Unmute' : 'Mute',
                      type: session.isMuted
                          ? CallButtonType.active
                          : CallButtonType.normal,
                      onPressed: () {
                        ref.read(callControllerProvider.notifier).toggleMicrophone();
                      },
                    ),

                    // Speaker Button
                    CallActionButton(
                      icon: session.isSpeakerOn
                          ? Icons.volume_up_rounded
                          : Icons.volume_down_rounded,
                      label: 'Speaker',
                      type: session.isSpeakerOn
                          ? CallButtonType.active
                          : CallButtonType.normal,
                      onPressed: () {
                        ref.read(callControllerProvider.notifier).toggleSpeaker();
                      },
                    ),

                    // End Call Button
                    CallActionButton(
                      icon: Icons.call_end_rounded,
                      label: 'End',
                      type: CallButtonType.endCall,
                      onPressed: () {
                        ref.read(callControllerProvider.notifier).endCall();
                      },
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
