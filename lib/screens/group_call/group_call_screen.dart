import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_radius.dart';
import '../../models/call_model.dart' show CallType;
import '../../models/group_call_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/group_call_provider.dart';
import '../../services/group_call_service.dart';
import '../../services/network_quality_service.dart';
import '../../services/permission_service.dart';
import '../../widgets/user_avatar.dart';

class GroupCallScreen extends ConsumerStatefulWidget {
  const GroupCallScreen({super.key});

  @override
  ConsumerState<GroupCallScreen> createState() => _GroupCallScreenState();
}

class _GroupCallScreenState extends ConsumerState<GroupCallScreen> {
  Future<void> _handleLeave(bool isHost) async {
    if (!isHost) {
      await ref.read(groupCallNotifierProvider.notifier).leaveCall();
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      return;
    }

    // Host can choose to end call for all or leave
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'End Group Call?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'As the host, you can end the call for everyone or leave the call.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('cancel'),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('leave'),
            child: const Text('Leave', style: TextStyle(color: Colors.orangeAccent)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop('end'),
            child: const Text('End for All', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (!mounted || action == null || action == 'cancel') return;

    await ref.read(groupCallNotifierProvider.notifier).leaveCall();
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(groupCallNotifierProvider);
    final service = ref.watch(groupCallServiceProvider);
    final currentUser = ref.watch(currentUserProvider);
    final engine = service.engine;
    final call = session.call;

    final isVideo = call?.callType == CallType.video;
    final isHost = call != null && currentUser != null && call.hostId == currentUser.id;
    final totalParticipants = session.remoteUids.length + 1;

    // Auto-pop GroupCallScreen if session is no longer joined (e.g. host ended call or disconnected)
    ref.listen(groupCallNotifierProvider, (previous, next) {
      if (previous?.isJoined == true && !next.isJoined) {
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      }
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) {
          await _handleLeave(isHost);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: SafeArea(
          child: Column(
            children: [
              // Top Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                      onPressed: () => _handleLeave(isHost),
                    ),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            call?.title ?? 'Group Call',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primaryBlue.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$totalParticipants Participant${totalParticipants == 1 ? '' : 's'}',
                              style: const TextStyle(
                                color: AppColors.primaryBlueLight,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.call_end_rounded, color: AppColors.error),
                      onPressed: () => _handleLeave(isHost),
                    ),
                  ],
                ),
              ),

              // Error Banner (e.g. Permissions or Connection)
              if (session.errorMessage != null)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          session.errorMessage!,
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                      if (session.errorMessage!.contains('Settings'))
                        TextButton(
                          onPressed: () => PermissionService().openAppSettings(),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: Size.zero,
                          ),
                          child: const Text('Settings', style: TextStyle(color: AppColors.primaryBlueLight, fontSize: 12)),
                        ),
                    ],
                  ),
                ),

              // Responsive Participant Video Grid
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: _buildParticipantGrid(
                    session: session,
                    engine: engine,
                    call: call,
                    currentUser: currentUser,
                    isVideo: isVideo,
                  ),
                ),
              ),

              // Bottom Control Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(
                  color: Color(0xFF1E293B),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Mute / Unmute
                    _buildControlButton(
                      isActive: session.isMuted,
                      activeColor: AppColors.error,
                      icon: session.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                      tooltip: session.isMuted ? 'Unmute' : 'Mute',
                      onPressed: () => ref.read(groupCallNotifierProvider.notifier).toggleMute(),
                    ),

                    // Camera On / Off (Video Calls Only)
                    if (isVideo) ...[
                      _buildControlButton(
                        isActive: session.isCameraOff,
                        activeColor: AppColors.error,
                        icon: session.isCameraOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
                        tooltip: session.isCameraOff ? 'Turn Camera On' : 'Turn Camera Off',
                        onPressed: () => ref.read(groupCallNotifierProvider.notifier).toggleCamera(),
                      ),

                      // Switch Camera
                      _buildControlButton(
                        isActive: false,
                        icon: Icons.flip_camera_ios_rounded,
                        tooltip: 'Flip Camera',
                        onPressed: () => ref.read(groupCallNotifierProvider.notifier).switchCamera(),
                      ),
                    ],

                    // Speakerphone Toggle
                    _buildControlButton(
                      isActive: session.isSpeakerOn,
                      activeColor: AppColors.primaryBlue,
                      icon: session.isSpeakerOn ? Icons.volume_up_rounded : Icons.hearing_rounded,
                      tooltip: session.isSpeakerOn ? 'Speaker On' : 'Earpiece',
                      onPressed: () => ref.read(groupCallNotifierProvider.notifier).toggleSpeaker(),
                    ),

                    // End / Leave Call
                    IconButton(
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.error,
                        padding: const EdgeInsets.all(14),
                      ),
                      icon: const Icon(Icons.call_end_rounded, color: Colors.white, size: 26),
                      onPressed: () => _handleLeave(isHost),
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

  Widget _buildControlButton({
    required bool isActive,
    Color? activeColor,
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    final bgColor = isActive
        ? (activeColor ?? AppColors.primaryBlue).withValues(alpha: 0.25)
        : Colors.white.withValues(alpha: 0.1);
    final iconColor = isActive
        ? (activeColor ?? AppColors.primaryBlueLight)
        : Colors.white;

    return Tooltip(
      message: tooltip,
      child: IconButton(
        style: IconButton.styleFrom(
          backgroundColor: bgColor,
          padding: const EdgeInsets.all(12),
        ),
        icon: Icon(icon, color: iconColor, size: 22),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildParticipantGrid({
    required GroupCallSession session,
    required RtcEngine? engine,
    required GroupCallModel? call,
    required UserModel? currentUser,
    required bool isVideo,
  }) {
    final remoteUidsList = session.remoteUids.toList();
    final total = remoteUidsList.length + 1;

    // Case 1: 1 participant (Local only, waiting)
    if (total == 1) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 220,
              height: 260,
              child: _buildLocalParticipantTile(
                isVideo: isVideo,
                session: session,
                engine: engine,
                name: currentUser?.name ?? 'You',
              ),
            ),
            const SizedBox(height: 20),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryBlueLight),
                ),
                SizedBox(width: 10),
                Text(
                  'Waiting for others to join...',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Case 2: 2 participants (A and B) -> 2 equal stacked tiles
    if (total == 2) {
      return Column(
        children: [
          Expanded(
            child: _buildLocalParticipantTile(
              isVideo: isVideo,
              session: session,
              engine: engine,
              name: '${currentUser?.name ?? "You"} (You)',
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _buildRemoteTileFromUid(
              remoteUid: remoteUidsList[0],
              isVideo: isVideo,
              session: session,
              engine: engine,
              call: call,
            ),
          ),
        ],
      );
    }

    // Case 3: 3 participants (A, B, C) -> 2 top row, 1 bottom row
    if (total == 3) {
      return Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _buildLocalParticipantTile(
                    isVideo: isVideo,
                    session: session,
                    engine: engine,
                    name: '${currentUser?.name ?? "You"} (You)',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildRemoteTileFromUid(
                    remoteUid: remoteUidsList[0],
                    isVideo: isVideo,
                    session: session,
                    engine: engine,
                    call: call,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _buildRemoteTileFromUid(
              remoteUid: remoteUidsList[1],
              isVideo: isVideo,
              session: session,
              engine: engine,
              call: call,
            ),
          ),
        ],
      );
    }

    // Case 4: 4 participants -> 2x2 grid
    if (total == 4) {
      return Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _buildLocalParticipantTile(
                    isVideo: isVideo,
                    session: session,
                    engine: engine,
                    name: '${currentUser?.name ?? "You"} (You)',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildRemoteTileFromUid(
                    remoteUid: remoteUidsList[0],
                    isVideo: isVideo,
                    session: session,
                    engine: engine,
                    call: call,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _buildRemoteTileFromUid(
                    remoteUid: remoteUidsList[1],
                    isVideo: isVideo,
                    session: session,
                    engine: engine,
                    call: call,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildRemoteTileFromUid(
                    remoteUid: remoteUidsList[2],
                    isVideo: isVideo,
                    session: session,
                    engine: engine,
                    call: call,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // Case 5+: 5 or more participants -> 2-column scrollable GridView
    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.85,
      ),
      itemCount: total,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildLocalParticipantTile(
            isVideo: isVideo,
            session: session,
            engine: engine,
            name: '${currentUser?.name ?? "You"} (You)',
          );
        }
        final remoteUid = remoteUidsList[index - 1];
        return _buildRemoteTileFromUid(
          remoteUid: remoteUid,
          isVideo: isVideo,
          session: session,
          engine: engine,
          call: call,
        );
      },
    );
  }

  Widget _buildRemoteTileFromUid({
    required int remoteUid,
    required bool isVideo,
    required GroupCallSession session,
    required RtcEngine? engine,
    required GroupCallModel? call,
  }) {
    final isRemoteCameraOff = session.remoteMutedVideos[remoteUid] ?? false;
    final participant = call?.getParticipantByAgoraUid(remoteUid);
    final quality = session.networkQualities[remoteUid];

    return _buildRemoteParticipantTile(
      remoteUid: remoteUid,
      isVideo: isVideo && !isRemoteCameraOff,
      engine: engine,
      channelName: call?.channelName ?? '',
      participantName: participant?.name,
      isMuted: participant?.isMuted ?? false,
      quality: quality,
    );
  }

  Widget _buildLocalParticipantTile({
    required bool isVideo,
    required GroupCallSession session,
    required RtcEngine? engine,
    required String name,
  }) {
    final showVideo = isVideo && !session.isCameraOff && engine != null;
    final quality = session.localUid != null ? session.networkQualities[session.localUid!] : null;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: AppRadius.roundedLg,
        border: Border.all(color: Colors.white12),
      ),
      child: ClipRRect(
        borderRadius: AppRadius.roundedLg,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (showVideo)
              AgoraVideoView(
                controller: VideoViewController(
                  rtcEngine: engine,
                  canvas: const VideoCanvas(uid: 0),
                ),
              )
            else
              UserAvatar(
                name: name,
                radius: 36,
              ),

            // Top-Right: Network Quality Badge
            if (quality != null)
              Positioned(
                top: 8,
                right: 8,
                child: _buildNetworkQualityBadge(quality),
              ),

            // Bottom-Left: Name & Mic Mute indicator
            Positioned(
              bottom: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (session.isMuted) ...[
                      const Icon(Icons.mic_off_rounded, color: AppColors.error, size: 14),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      name,
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom-Right: Camera Off indicator
            if (isVideo && session.isCameraOff)
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.videocam_off_rounded, color: AppColors.error, size: 14),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRemoteParticipantTile({
    required int remoteUid,
    required bool isVideo,
    required RtcEngine? engine,
    required String channelName,
    String? participantName,
    bool isMuted = false,
    QualityType? quality,
  }) {
    final showVideo = isVideo && engine != null && channelName.isNotEmpty;
    final displayName = participantName ?? 'User $remoteUid';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: AppRadius.roundedLg,
        border: Border.all(color: Colors.white12),
      ),
      child: ClipRRect(
        borderRadius: AppRadius.roundedLg,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (showVideo)
              AgoraVideoView(
                controller: VideoViewController.remote(
                  rtcEngine: engine,
                  canvas: VideoCanvas(uid: remoteUid),
                  connection: RtcConnection(channelId: channelName),
                ),
              )
            else
              UserAvatar(
                name: displayName,
                radius: 36,
              ),

            // Top-Right: Network Quality Badge
            if (quality != null)
              Positioned(
                top: 8,
                right: 8,
                child: _buildNetworkQualityBadge(quality),
              ),

            // Bottom-Left: Name & Mic Mute indicator
            Positioned(
              bottom: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isMuted) ...[
                      const Icon(Icons.mic_off_rounded, color: AppColors.error, size: 14),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      displayName,
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom-Right: Camera Off indicator
            if (!showVideo)
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.videocam_off_rounded, color: AppColors.error, size: 14),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNetworkQualityBadge(QualityType quality) {
    final qualityLevel = NetworkQualityService.fromAgoraQuality(quality);
    if (qualityLevel == NetworkCallQuality.unknown) {
      return const SizedBox.shrink();
    }

    final Color dotColor;
    switch (qualityLevel) {
      case NetworkCallQuality.good:
        dotColor = Colors.greenAccent;
        break;
      case NetworkCallQuality.fair:
        dotColor = Colors.amberAccent;
        break;
      case NetworkCallQuality.poor:
        dotColor = AppColors.error;
        break;
      default:
        dotColor = Colors.greenAccent;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            qualityLevel.label,
            style: TextStyle(color: dotColor, fontSize: 10, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
