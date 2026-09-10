import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_radius.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/call_model.dart';
import '../../providers/call_provider.dart';
import '../../widgets/call_action_button.dart';
import '../../widgets/user_avatar.dart';

class VideoCallScreen extends ConsumerStatefulWidget {
  const VideoCallScreen({super.key});

  @override
  ConsumerState<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends ConsumerState<VideoCallScreen> {
  // Draggable preview offset
  Offset _pipOffset = const Offset(20, 90);

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(callControllerProvider);
    final callingService = ref.watch(callingServiceProvider);
    final call = session.call;

    // Listen for call ending to pop screen
    ref.listen(callControllerProvider, (previous, next) {
      if (next.status == CallStatus.ended ||
          next.status == CallStatus.rejected ||
          next.status == CallStatus.failed) {
        final nav = Navigator.of(context);
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted && nav.canPop()) {
            nav.pop();
          }
        });
      }
    });

    final screenSize = MediaQuery.of(context).size;
    final otherPartyName = call?.calleeName ?? 'Unknown';

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: Stack(
        children: [
          // 1. Remote Video Feed (Full Screen)
          Positioned.fill(
            child: session.isRemoteStreamReady
                ? RTCVideoView(
                    callingService.remoteRenderer,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  )
                : Container(
                    color: AppColors.darkBackground,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          UserAvatar(
                            name: otherPartyName,
                            photoUrl: call?.calleePhoto,
                            radius: 60,
                          ),
                          const SizedBox(height: 18),
                          Text(
                            otherPartyName,
                            style: AppTextStyles.h2(color: AppColors.darkPrimaryText),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            session.status == CallStatus.inCall
                                ? 'Connecting video stream...'
                                : (session.status == CallStatus.calling
                                    ? 'Calling...'
                                    : 'Ringing...'),
                            style: AppTextStyles.body(color: AppColors.cyan),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),

          // 2. Top Info Header (Gradient Overlay + Caller Name & Duration)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                left: 16,
                right: 16,
                bottom: 24,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.8),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
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
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          otherPartyName,
                          style: AppTextStyles.title(color: AppColors.white),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          session.status == CallStatus.inCall
                              ? DateFormatter.formatDuration(session.durationSeconds)
                              : 'Connecting...',
                          style: AppTextStyles.caption(color: AppColors.cyan),
                        ),
                      ],
                    ),
                  ),
                  // Switch camera shortcut in top bar
                  IconButton(
                    icon: const Icon(Icons.flip_camera_ios_rounded,
                        color: AppColors.white, size: 24),
                    onPressed: () {
                      ref.read(callControllerProvider.notifier).switchCamera();
                    },
                  ),
                ],
              ),
            ),
          ),

          // 3. Draggable Floating Local Camera Preview (PIP)
          Positioned(
            left: _pipOffset.dx,
            top: _pipOffset.dy,
            child: GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  _pipOffset = Offset(
                    (_pipOffset.dx + details.delta.dx)
                        .clamp(16.0, screenSize.width - 136.0),
                    (_pipOffset.dy + details.delta.dy)
                        .clamp(60.0, screenSize.height - 240.0),
                  );
                });
              },
              child: Container(
                width: 120,
                height: 165,
                decoration: BoxDecoration(
                  color: AppColors.darkSurface,
                  borderRadius: AppRadius.roundedLg,
                  border: Border.all(color: AppColors.primaryBlueLight, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: session.isCameraOff
                      ? Container(
                          color: AppColors.darkSurface,
                          child: const Center(
                            child: Icon(Icons.videocam_off_rounded,
                                color: AppColors.darkMutedText, size: 32),
                          ),
                        )
                      : RTCVideoView(
                          callingService.localRenderer,
                          mirror: session.isFrontCamera,
                          objectFit:
                              RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                        ),
                ),
              ),
            ),
          ),

          // 4. Floating Bottom Call Controls Bar
          Positioned(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).padding.bottom + 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.darkSurface.withValues(alpha: 0.88),
                borderRadius: AppRadius.roundedXl,
                border: Border.all(color: AppColors.darkBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Mute Microphone
                  CallActionButton(
                    icon: session.isMuted
                        ? Icons.mic_off_rounded
                        : Icons.mic_rounded,
                    label: session.isMuted ? 'Unmute' : 'Mute',
                    type: session.isMuted
                        ? CallButtonType.active
                        : CallButtonType.normal,
                    size: 48,
                    onPressed: () {
                      ref.read(callControllerProvider.notifier).toggleMicrophone();
                    },
                  ),

                  // Camera On / Off
                  CallActionButton(
                    icon: session.isCameraOff
                        ? Icons.videocam_off_rounded
                        : Icons.videocam_rounded,
                    label: session.isCameraOff ? 'Cam Off' : 'Camera',
                    type: session.isCameraOff
                        ? CallButtonType.active
                        : CallButtonType.normal,
                    size: 48,
                    onPressed: () {
                      ref.read(callControllerProvider.notifier).toggleCamera();
                    },
                  ),

                  // Switch Front/Rear Camera
                  CallActionButton(
                    icon: Icons.switch_camera_rounded,
                    label: 'Switch',
                    size: 48,
                    onPressed: () {
                      ref.read(callControllerProvider.notifier).switchCamera();
                    },
                  ),

                  // End Call
                  CallActionButton(
                    icon: Icons.call_end_rounded,
                    label: 'End',
                    type: CallButtonType.endCall,
                    size: 48,
                    onPressed: () {
                      ref.read(callControllerProvider.notifier).endCall();
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
