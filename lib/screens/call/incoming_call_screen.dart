import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/call_model.dart';
import '../../providers/call_provider.dart';
import '../../widgets/call_action_button.dart';
import '../../widgets/user_avatar.dart';
import 'audio_call_screen.dart';
import 'video_call_screen.dart';

import '../../core/services/ringtone_service.dart';

class IncomingCallScreen extends ConsumerStatefulWidget {
  const IncomingCallScreen({super.key});

  @override
  ConsumerState<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends ConsumerState<IncomingCallScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _rippleController;
  late Animation<double> _rippleAnimation;
  final RingtoneService _ringtoneService = RingtoneService();
  bool _isAccepting = false;

  @override
  void initState() {
    super.initState();
    final call = ref.read(callControllerProvider).call;
    debugPrint('[CALL FLOW] callId=${call?.id} role=receiver step=INCOMING_RECEIVED timestamp=${DateTime.now().toIso8601String()}');
    debugPrint('[INCOMING TRACE] 03 ringtone START');
    _ringtoneService.startRingtone();
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _rippleAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _rippleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ringtoneService.stopRingtone();
    _rippleController.dispose();
    super.dispose();
  }

  Future<void> _handleAccept() async {
    if (_isAccepting) return;
    _isAccepting = true;

    final session = ref.read(callControllerProvider);
    final call = session.call;
    debugPrint('[CALL FLOW] callId=${call?.id} role=receiver step=ACCEPT_PRESSED timestamp=${DateTime.now().toIso8601String()}');
    debugPrint('[ACCEPT DEBUG] 01 accept pressed');
    await _ringtoneService.stopRingtone();
    debugPrint('[CALL FLOW] callId=${call?.id} role=receiver step=RING_TIMEOUT_CANCELLED timestamp=${DateTime.now().toIso8601String()}');
    debugPrint('[ACCEPT DEBUG] 02 call loaded (callId: ${call?.id})');
    debugPrint('[ACCEPT DEBUG] 03 current call status=${session.status.name}');

    final success = await ref.read(callControllerProvider.notifier).acceptCall();

    if (!mounted) return;

    if (!success) {
      _isAccepting = false;
      final currentSession = ref.read(callControllerProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(currentSession.errorMessage ?? 'This call is no longer available.'),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 3),
          action: (currentSession.errorMessage?.contains('Settings') ?? false)
              ? SnackBarAction(
                  label: 'Settings',
                  textColor: Colors.white,
                  onPressed: () => ref.read(permissionServiceProvider).openAppSettings(),
                )
              : null,
        ),
      );
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      return;
    }

    debugPrint('[CALL FLOW] callId=${call?.id} role=receiver step=STATUS_UPDATE_ACCEPTED timestamp=${DateTime.now().toIso8601String()}');

    final isVideo = ref.read(callControllerProvider).call?.callType == CallType.video;
    debugPrint('[ACCEPT DEBUG] navigation to CallScreen START');
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => isVideo ? const VideoCallScreen() : const AudioCallScreen(),
      ),
    );
    debugPrint('[ACCEPT DEBUG] navigation to CallScreen END');
  }

  Future<void> _handleDecline() async {
    await _ringtoneService.stopRingtone();
    await ref.read(callControllerProvider.notifier).rejectCall();
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(callControllerProvider);
    final call = session.call;

    // Listen for call cancellation by caller before acceptance
    ref.listen(callControllerProvider, (previous, next) {
      if (_isAccepting) return; // Don't interrupt in-flight acceptance navigation
      if (next.status == CallStatus.ended ||
          next.status == CallStatus.missed ||
          next.status == CallStatus.rejected ||
          next.status == CallStatus.failed) {
        _ringtoneService.stopRingtone();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Call ended'),
              duration: Duration(seconds: 2),
            ),
          );
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        }
      }
    });

    final isVideo = call?.callType == CallType.video;
    final callerName = call?.callerName ?? 'Unknown Caller';

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
              const Spacer(flex: 1),

              // Call Type Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.darkElevatedSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.darkBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isVideo ? Icons.videocam_rounded : Icons.phone_rounded,
                      color: AppColors.cyan,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isVideo ? 'Incoming Video Call' : 'Incoming Audio Call',
                      style: AppTextStyles.bodyMedium(color: AppColors.white),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Caller Name
              Text(
                callerName,
                style: AppTextStyles.h1(color: AppColors.darkPrimaryText),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              Text(
                'ConnectCall User',
                style: AppTextStyles.body(color: AppColors.darkMutedText),
              ),

              const SizedBox(height: AppSpacing.xxxl),

              // Pulsing Caller Avatar
              ScaleTransition(
                scale: _rippleAnimation,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (isVideo ? AppColors.cyan : AppColors.primaryBlueLight)
                            .withValues(alpha: 0.35),
                        blurRadius: 36,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                  child: UserAvatar(
                    name: callerName,
                    photoUrl: call?.callerPhoto,
                    radius: 70,
                  ),
                ),
              ),

              const Spacer(flex: 2),

              // Accept & Decline Buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Decline Button (Red)
                    CallActionButton(
                      icon: Icons.call_end_rounded,
                      label: 'Decline',
                      semanticLabel: 'Reject call',
                      type: CallButtonType.endCall,
                      size: 64,
                      onPressed: _handleDecline,
                    ),

                    // Accept Button (Green)
                    CallActionButton(
                      icon: isVideo ? Icons.videocam_rounded : Icons.phone_rounded,
                      label: 'Accept',
                      semanticLabel: 'Accept call',
                      type: CallButtonType.acceptCall,
                      size: 64,
                      onPressed: _handleAccept,
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
