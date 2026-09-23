import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/call_model.dart';
import '../../providers/auth_provider.dart';
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final session = ref.read(callControllerProvider);
      final currentUser = ref.read(currentUserProvider);
      final isCaller = currentUser?.id == session.call?.callerId;
      debugPrint('[CALL TRACE 05] Calling screen opened (AudioCallScreen mounted, callId: ${session.call?.id}, isCaller: $isCaller)');
      if (isCaller) {
        debugPrint('[CALL TRACE] AudioCallScreen mounted for caller; connecting Agora');
        ref.read(callingServiceProvider).connectAgoraForCaller();
      } else {
        debugPrint('[CALL TRACE] AudioCallScreen mounted for receiver; connecting Agora');
        ref.read(callingServiceProvider).connectAgoraForReceiver();
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String _getStatusText(CallStatus status, [String? errorMessage]) {
    if (errorMessage != null && errorMessage.isNotEmpty) {
      return errorMessage;
    }
    switch (status) {
      case CallStatus.calling:
        return 'Calling...';
      case CallStatus.ringing:
        return 'Ringing...';
      case CallStatus.connecting:
      case CallStatus.accepted:
        return 'Connecting...';
      case CallStatus.connected:
      case CallStatus.inCall:
        return 'Connected';
      case CallStatus.reconnecting:
        return 'Reconnecting...';
      case CallStatus.ended:
        return 'Call Ended';
      case CallStatus.rejected:
        return 'Call Declined';
      case CallStatus.missed:
        return 'No Answer / Call Missed';
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
    final currentUser = ref.watch(currentUserProvider);

    // Listen for ended, rejected, or missed state to auto-close screen
    ref.listen(callControllerProvider, (previous, next) {
      if (next.status == CallStatus.ended ||
          next.status == CallStatus.rejected ||
          next.status == CallStatus.missed ||
          next.status == CallStatus.failed) {
        final nav = Navigator.of(context);
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted && nav.canPop()) {
            nav.pop();
          }
        });
      }
    });

    final isCallActive = session.status == CallStatus.inCall || session.status == CallStatus.connected;

    // Dynamically identify other party (if current user is caller, display callee; if callee, display caller)
    final isCaller = currentUser?.id == call?.callerId;
    final otherPartyName = isCaller
        ? (call?.calleeName.isNotEmpty == true ? call!.calleeName : 'Recipient')
        : (call?.callerName.isNotEmpty == true ? call!.callerName : 'Caller');
    final otherPartyPhoto = isCaller ? call?.calleePhoto : call?.callerPhoto;

    return PopScope(
      canPop: session.status == CallStatus.ended ||
          session.status == CallStatus.rejected ||
          session.status == CallStatus.missed ||
          session.status == CallStatus.failed,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          final nav = Navigator.of(context);
          // Gracefully terminate call if back button is pressed
          await ref.read(callControllerProvider.notifier).endCall();
          if (nav.canPop()) {
            nav.pop();
          }
        }
      },
      child: Scaffold(
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
                        onPressed: () async {
                          await ref.read(callControllerProvider.notifier).endCall();
                          if (context.mounted && Navigator.of(context).canPop()) {
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
              if (session.status == CallStatus.reconnecting)
                Text(
                  'Reconnecting...',
                  style: AppTextStyles.callDuration(color: Colors.amberAccent),
                )
              else if (isCallActive)
                Text(
                  DateFormatter.formatDuration(session.durationSeconds),
                  style: AppTextStyles.callDuration(color: AppColors.cyan),
                )
              else
                Text(
                  _getStatusText(session.status, session.errorMessage),
                  style: AppTextStyles.title(color: AppColors.darkMutedText),
                ),

              // Network Quality Indicator (Bonus 6)
              if (isCallActive) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        session.networkQuality.emoji,
                        style: const TextStyle(fontSize: 11),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${session.networkQuality.label} Quality',
                        style: AppTextStyles.caption(
                          color: AppColors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

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
                      semanticLabel: session.isMuted ? 'Unmute microphone' : 'Mute microphone',
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
                      semanticLabel: session.isSpeakerOn ? 'Turn speaker off' : 'Turn speaker on',
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
                      semanticLabel: 'End call',
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
    ),
  );
}
}
