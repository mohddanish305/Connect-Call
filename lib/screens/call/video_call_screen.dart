import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_radius.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/call_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/call_provider.dart';
import '../../widgets/call_action_button.dart';
import '../../widgets/user_avatar.dart';

class VideoCallScreen extends ConsumerStatefulWidget {
  const VideoCallScreen({super.key});

  @override
  ConsumerState<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends ConsumerState<VideoCallScreen> {
  // Draggable preview offset for local PIP
  Offset _pipOffset = const Offset(16, 90);

  // Cached Agora video view controllers to avoid recreating inside build()
  VideoViewController? _localViewController;
  VideoViewController? _remoteViewController;
  int? _cachedRemoteUid;
  String? _cachedChannelName;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final session = ref.read(callControllerProvider);
      final currentUser = ref.read(currentUserProvider);
      final isCaller = currentUser?.id == session.call?.callerId;
      debugPrint('[CALL TRACE 05] Calling screen opened (VideoCallScreen mounted, callId: ${session.call?.id}, isCaller: $isCaller)');
      if (isCaller) {
        debugPrint('[CALL TRACE] VideoCallScreen mounted for caller; connecting Agora');
        ref.read(callingServiceProvider).connectAgoraForCaller();
      } else {
        debugPrint('[CALL TRACE] VideoCallScreen mounted for receiver; connecting Agora');
        ref.read(callingServiceProvider).connectAgoraForReceiver();
      }
    });
  }

  @override
  void dispose() {
    _localViewController?.dispose();
    _remoteViewController?.dispose();
    super.dispose();
  }

  void _syncControllers({
    required RtcEngine? agoraEngine,
    required bool hasLocalVideo,
    required bool hasRemoteVideo,
    required int? remoteUid,
    required String? channelName,
  }) {
    if (agoraEngine == null) return;

    // Local controller
    if (hasLocalVideo && _localViewController == null) {
      _localViewController = VideoViewController(
        rtcEngine: agoraEngine,
        canvas: const VideoCanvas(uid: 0),
      );
    } else if (!hasLocalVideo && _localViewController != null) {
      _localViewController?.dispose();
      _localViewController = null;
    }

    // Remote controller
    if (hasRemoteVideo && remoteUid != null && channelName != null) {
      if (_remoteViewController == null ||
          _cachedRemoteUid != remoteUid ||
          _cachedChannelName != channelName) {
        _remoteViewController?.dispose();
        _cachedRemoteUid = remoteUid;
        _cachedChannelName = channelName;
        _remoteViewController = VideoViewController.remote(
          rtcEngine: agoraEngine,
          canvas: VideoCanvas(uid: remoteUid),
          connection: RtcConnection(channelId: channelName),
        );
      }
    } else if (!hasRemoteVideo && _remoteViewController != null) {
      _remoteViewController?.dispose();
      _remoteViewController = null;
      _cachedRemoteUid = null;
      _cachedChannelName = null;
    }
  }

  String _getStatusText(CallStatus status, String? errorMessage) {
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
        return 'Connecting video stream...';
      case CallStatus.connected:
      case CallStatus.inCall:
        return 'Connected';
      case CallStatus.reconnecting:
        return 'Reconnecting video...';
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
    final callingService = ref.watch(callingServiceProvider);
    final agoraEngine = callingService.agoraService.engine;
    final call = session.call;
    final currentUser = ref.watch(currentUserProvider);

    // Listen for call termination to automatically close screen
    ref.listen(callControllerProvider, (previous, next) {
      if (next.status == CallStatus.ended ||
          next.status == CallStatus.rejected ||
          next.status == CallStatus.missed ||
          next.status == CallStatus.failed) {
        final nav = Navigator.of(context);
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted && nav.canPop()) {
            nav.pop();
          }
        });
      }
    });

    final screenSize = MediaQuery.of(context).size;
    final isCaller = currentUser?.id == call?.callerId;
    final otherPartyName = isCaller
        ? (call?.calleeName.isNotEmpty == true ? call!.calleeName : 'Recipient')
        : (call?.callerName.isNotEmpty == true ? call!.callerName : 'Caller');
    final otherPartyPhoto = isCaller ? call?.calleePhoto : call?.callerPhoto;

    final isCallActive =
        session.status == CallStatus.inCall || session.status == CallStatus.connected;

    final hasRemoteVideo = isCallActive &&
        session.remoteUid != null &&
        !session.isRemoteCameraOff &&
        agoraEngine != null &&
        call != null;

    final hasLocalVideo = !session.isCameraOff && agoraEngine != null;

    // Sync controllers safely without recreation inside build
    _syncControllers(
      agoraEngine: agoraEngine,
      hasLocalVideo: hasLocalVideo,
      hasRemoteVideo: hasRemoteVideo,
      remoteUid: session.remoteUid,
      channelName: call?.channelName,
    );

    return PopScope(
      canPop: session.status == CallStatus.ended ||
          session.status == CallStatus.rejected ||
          session.status == CallStatus.missed ||
          session.status == CallStatus.failed,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          final nav = Navigator.of(context);
          await ref.read(callControllerProvider.notifier).endCall();
          if (nav.canPop()) {
            nav.pop();
          }
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.darkBackground,
        body: Stack(
          children: [
            // ===============================================================
            // 1. Remote Video Surface (Full Screen)
            // ===============================================================
            Positioned.fill(
              child: hasRemoteVideo && _remoteViewController != null
                  ? AgoraVideoView(
                      controller: _remoteViewController!,
                    )
                  : Container(
                      color: AppColors.darkBackground,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            UserAvatar(
                              name: otherPartyName,
                              photoUrl: otherPartyPhoto,
                              radius: 64,
                            ),
                            const SizedBox(height: 20),
                            Text(
                              otherPartyName,
                              style: AppTextStyles.h2(color: AppColors.darkPrimaryText),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              session.isRemoteCameraOff && isCallActive
                                  ? 'Camera is off'
                                  : _getStatusText(session.status, session.errorMessage),
                              style: AppTextStyles.body(
                                color: session.isRemoteCameraOff
                                    ? AppColors.darkMutedText
                                    : AppColors.cyan,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
            ),

            // ===============================================================
            // 2. Top Bar (Overlay Gradient + Participant Name & Duration)
            // ===============================================================
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
                      Colors.black.withValues(alpha: 0.85),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down_rounded,
                          color: AppColors.white, size: 28),
                      tooltip: 'Minimize call',
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
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  session.status == CallStatus.reconnecting
                                      ? 'Reconnecting...'
                                      : (isCallActive
                                          ? DateFormatter.formatDuration(session.durationSeconds)
                                          : _getStatusText(session.status, session.errorMessage)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.caption(
                                    color: session.status == CallStatus.reconnecting
                                        ? Colors.amberAccent
                                        : (isCallActive ? AppColors.cyan : AppColors.darkMutedText),
                                  ),
                                ),
                              ),
                              if (isCallActive) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.35),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        session.networkQuality.emoji,
                                        style: const TextStyle(fontSize: 9),
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        session.networkQuality.label,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Quick front/rear camera switch
                    IconButton(
                      icon: const Icon(Icons.flip_camera_ios_rounded,
                          color: AppColors.white, size: 24),
                      tooltip: 'Switch camera',
                      onPressed: () {
                        ref.read(callControllerProvider.notifier).switchCamera();
                      },
                    ),
                  ],
                ),
              ),
            ),

            // ===============================================================
            // 3. Draggable Floating Local Camera Preview (PIP)
            // ===============================================================
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
                  width: 116,
                  height: 156,
                  decoration: BoxDecoration(
                    color: AppColors.darkSurface,
                    borderRadius: AppRadius.roundedLg,
                    border: Border.all(color: AppColors.primaryBlueLight, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: hasLocalVideo && _localViewController != null
                        ? AgoraVideoView(
                            controller: _localViewController!,
                          )
                        : Container(
                            color: AppColors.darkSurface,
                            padding: const EdgeInsets.all(8),
                            child: const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.videocam_off_rounded,
                                    color: AppColors.darkMutedText,
                                    size: 28,
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    'Camera Off',
                                    style: TextStyle(
                                      color: AppColors.darkMutedText,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                  ),
                ),
              ),
            ),

            // ===============================================================
            // 4. Floating Bottom Call Controls Bar
            // ===============================================================
            Positioned(
              left: 16,
              right: 16,
              bottom: MediaQuery.of(context).padding.bottom + 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.darkSurface.withValues(alpha: 0.92),
                  borderRadius: AppRadius.roundedXl,
                  border: Border.all(color: AppColors.darkBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Mute / Unmute Microphone
                    CallActionButton(
                      icon: session.isMuted
                          ? Icons.mic_off_rounded
                          : Icons.mic_rounded,
                      label: session.isMuted ? 'Unmute' : 'Mute',
                      semanticLabel: session.isMuted ? 'Unmute microphone' : 'Mute microphone',
                      type: session.isMuted
                          ? CallButtonType.active
                          : CallButtonType.normal,
                      size: 44,
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
                      semanticLabel: session.isCameraOff ? 'Turn camera on' : 'Turn camera off',
                      type: session.isCameraOff
                          ? CallButtonType.active
                          : CallButtonType.normal,
                      size: 44,
                      onPressed: () {
                        ref.read(callControllerProvider.notifier).toggleCamera();
                      },
                    ),

                    // Switch Front / Rear Camera
                    CallActionButton(
                      icon: Icons.flip_camera_ios_rounded,
                      label: 'Switch',
                      semanticLabel: 'Switch camera',
                      size: 44,
                      onPressed: () {
                        ref.read(callControllerProvider.notifier).switchCamera();
                      },
                    ),

                    // Speakerphone Toggle
                    CallActionButton(
                      icon: session.isSpeakerOn
                          ? Icons.volume_up_rounded
                          : Icons.volume_down_rounded,
                      label: 'Speaker',
                      semanticLabel: session.isSpeakerOn ? 'Turn speaker off' : 'Turn speaker on',
                      type: session.isSpeakerOn
                          ? CallButtonType.active
                          : CallButtonType.normal,
                      size: 44,
                      onPressed: () {
                        ref.read(callControllerProvider.notifier).toggleSpeaker();
                      },
                    ),

                    // End Video Call
                    CallActionButton(
                      icon: Icons.call_end_rounded,
                      label: 'End',
                      semanticLabel: 'End call',
                      type: CallButtonType.endCall,
                      size: 44,
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
      ),
    );
  }
}
