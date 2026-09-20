import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/ringtone_service.dart';
import '../../models/call_model.dart' show CallType;
import '../../models/group_call_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/group_call_provider.dart';
import '../../widgets/user_avatar.dart';
import 'group_call_screen.dart';

class IncomingGroupCallDialog extends ConsumerStatefulWidget {
  final GroupCallModel groupCall;

  const IncomingGroupCallDialog({
    super.key,
    required this.groupCall,
  });

  @override
  ConsumerState<IncomingGroupCallDialog> createState() => _IncomingGroupCallDialogState();
}

class _IncomingGroupCallDialogState extends ConsumerState<IncomingGroupCallDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _rippleController;
  late Animation<double> _rippleAnimation;
  final RingtoneService _ringtoneService = RingtoneService();
  Timer? _ringingTimeoutTimer;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _groupCallSub;
  bool _isActionTaken = false;

  @override
  void initState() {
    super.initState();
    _ringtoneService.startRingtone();
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _rippleAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _rippleController, curve: Curves.easeInOut),
    );

    // 30-Second Ringing Timeout: Auto-dismiss if not answered
    _ringingTimeoutTimer = Timer(const Duration(seconds: 30), () {
      debugPrint('[IncomingGroupCallDialog] Ringing timeout (30s) reached for groupCall: ${widget.groupCall.id}');
      _dismissSafely();
    });

    // In-dialog Firestore listener: auto-dismiss if host ends/cancels or user leaves
    _groupCallSub = FirebaseFirestore.instance
        .collection('groupCalls')
        .doc(widget.groupCall.id)
        .snapshots()
        .listen((snap) {
      if (!snap.exists || snap.data() == null) {
        debugPrint('[IncomingGroupCallDialog] Group call doc deleted. Dismissing.');
        _dismissSafely();
        return;
      }
      final data = snap.data()!;
      final isActive = data['isActive'] == true;
      if (!isActive) {
        debugPrint('[IncomingGroupCallDialog] Group call became inactive. Dismissing.');
        _dismissSafely();
        return;
      }

      final currentUid = ref.read(currentUserProvider)?.id ?? FirebaseAuth.instance.currentUser?.uid;
      if (currentUid != null) {
        final participants = data['participants'] as Map<String, dynamic>?;
        final myData = participants?[currentUid] as Map<String, dynamic>?;
        if (myData != null) {
          final status = myData['status'] as String?;
          final hasLeft = myData['hasLeft'] == true;
          if (hasLeft || status == 'left' || status == 'declined' || status == 'ended') {
            debugPrint('[IncomingGroupCallDialog] Participant status became $status. Dismissing.');
            _dismissSafely();
            return;
          }
        }
      }
    });
  }

  void _dismissSafely() {
    if (_isActionTaken) return;
    _isActionTaken = true;
    _ringtoneService.stopRingtone();
    _ringingTimeoutTimer?.cancel();
    _groupCallSub?.cancel();
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _ringtoneService.stopRingtone();
    _ringingTimeoutTimer?.cancel();
    _groupCallSub?.cancel();
    _rippleController.dispose();
    super.dispose();
  }

  Future<void> _handleAccept() async {
    if (_isActionTaken) return;
    _isActionTaken = true;

    await _ringtoneService.stopRingtone();
    _ringingTimeoutTimer?.cancel();
    _groupCallSub?.cancel();

    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      return;
    }

    // Dismiss dialog FIRST so no modal remains stuck behind GroupCallScreen
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }

    // Push GroupCallScreen immediately
    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const GroupCallScreen()),
      );
    }

    // Connect to Agora channel asynchronously
    final service = ref.read(groupCallServiceProvider);
    final success = await service.acceptGroupCallInvitation(widget.groupCall, currentUser.id);

    if (!success) {
      debugPrint('[IncomingGroupCallDialog] Failed to join group call after accept.');
    }
  }

  Future<void> _handleDecline() async {
    if (_isActionTaken) return;
    _isActionTaken = true;

    await _ringtoneService.stopRingtone();
    _ringingTimeoutTimer?.cancel();
    _groupCallSub?.cancel();

    final currentUser = ref.read(currentUserProvider);
    if (currentUser != null) {
      final service = ref.read(groupCallServiceProvider);
      await service.declineGroupCallInvitation(widget.groupCall, currentUser.id);
    }

    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.groupCall.callType == CallType.video;
    final totalParticipants = widget.groupCall.participantIds.length;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleDecline();
      },
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header tag
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isVideo ? Icons.videocam_rounded : Icons.phone_rounded,
                      color: AppColors.primaryBlueLight,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isVideo ? 'Incoming Group Video Call' : 'Incoming Group Audio Call',
                      style: const TextStyle(
                        color: AppColors.primaryBlueLight,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Animated Host Avatar with ripple
              AnimatedBuilder(
                animation: _rippleAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _rippleAnimation.value,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryBlue.withValues(alpha: 0.25),
                            blurRadius: 20,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: UserAvatar(
                        name: widget.groupCall.hostName,
                        radius: 44,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 20),

              // Group Title
              Text(
                widget.groupCall.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 6),

              // Host subtitle
              Text(
                'Invited by ${widget.groupCall.hostName}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 4),

              Text(
                '$totalParticipants participants invited',
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 12,
                ),
              ),

              const SizedBox(height: 32),

              // Action buttons (Decline / Accept)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Decline Button
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: _handleDecline,
                        borderRadius: BorderRadius.circular(32),
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: const BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.call_end_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Decline',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),

                  // Accept Button
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: _handleAccept,
                        borderRadius: BorderRadius.circular(32),
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: const BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Accept',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
