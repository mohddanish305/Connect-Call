import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../core/config/agora_debug_config.dart';
import '../core/services/agora_service.dart';
import '../core/services/network_service.dart';
import '../core/services/permission_service.dart';
import '../models/call_model.dart';
import '../models/call_session.dart';
import '../models/user_model.dart';
import '../services/call_signaling_service.dart';
import '../services/calling_service.dart';
import 'auth_provider.dart';
import 'call_history_provider.dart';

final permissionServiceProvider = Provider<PermissionService>((ref) {
  return PermissionService();
});

final networkServiceProvider = Provider<NetworkService>((ref) {
  return NetworkService();
});

final agoraServiceProvider = Provider<AgoraService>((ref) {
  final service = AgoraService();
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});

final callSignalingServiceProvider = Provider<CallSignalingService>((ref) {
  return CallSignalingService();
});

final callingServiceProvider = Provider<CallingService>((ref) {
  final historyService = ref.watch(callHistoryServiceProvider);
  final agoraService = ref.watch(agoraServiceProvider);
  final signalingService = ref.watch(callSignalingServiceProvider);
  final networkService = ref.watch(networkServiceProvider);

  final service = CallingService(
    agoraService: agoraService,
    historyService: historyService,
    signalingService: signalingService,
    networkService: networkService,
  );

  ref.onDispose(() {
    service.dispose();
  });
  return service;
});

/// Stream of active incoming calls targeted at the current authenticated user from Firestore
final incomingCallsStreamProvider = StreamProvider.autoDispose<List<CallModel>>((ref) {
  final currentUser = ref.watch(currentUserProvider);
  if (currentUser == null) return const Stream.empty();
  final signaling = ref.watch(callSignalingServiceProvider);
  return signaling.streamIncomingCalls(currentUser.id);
});

class CallController extends StateNotifier<CallSession> {
  final CallingService _callingService;
  final PermissionService _permissionService;
  final Ref _ref;

  CallController(this._callingService, this._permissionService, this._ref)
      : super(const CallSession()) {
    _callingService.onSessionChanged = (session) {
      state = session;
      if (session.status == CallStatus.ended || session.status == CallStatus.rejected) {
        // Refresh history
        _ref.read(callHistoryNotifierProvider.notifier).loadHistory();
      }
    };

    // Clean up call safely if user logs out during an active call (Section 26 & 36)
    _ref.listen<UserModel?>(currentUserProvider, (previous, next) {
      if (next == null &&
          state.call != null &&
          state.status != CallStatus.ended &&
          state.status != CallStatus.rejected &&
          state.status != CallStatus.missed &&
          state.status != CallStatus.failed) {
        endCall();
        resetSession();
      }
    });
  }

  /// Start an outgoing audio call
  Future<bool> startAudioCall({
    required UserModel targetUser,
    String? channelName,
  }) async {
    return startCall(
      targetUser: targetUser,
      callType: CallType.audio,
      customChannelName: channelName,
    );
  }

  /// Start an outgoing video call
  Future<bool> startVideoCall({
    required UserModel targetUser,
    String? channelName,
  }) async {
    return startCall(
      targetUser: targetUser,
      callType: CallType.video,
      customChannelName: channelName,
    );
  }

  Future<bool> startCall({
    required UserModel targetUser,
    required CallType callType,
    String? customChannelName,
  }) async {
    final fbUser = FirebaseAuth.instance.currentUser;
    debugPrint('[CALL TRACE 01] call button pressed (caller: ${fbUser?.uid}, target: ${targetUser.id}, callType: ${callType.name})');
    debugPrint('[CALL TRACE] CallNotifier.startCall START (callType: ${callType.name}, target: ${targetUser.id})');
    debugPrint('[CALL TRACE] 02 auth check START');
    final currentUser = _ref.read(currentUserProvider);
    debugPrint('[CALL TRACE] 03 auth check END uid=${fbUser?.uid}');

    if (fbUser == null) {
      debugPrint('[CALL TRACE] Call failed: No authenticated Firebase user');
      state = state.copyWith(
        status: CallStatus.failed,
        errorMessage: 'You must be signed in to make calls.',
      );
      return false;
    }

    // Check permissions
    debugPrint('[CALL TRACE] permission check START');
    final permStatus = callType == CallType.video
        ? await _permissionService.requestVideoPermissions()
        : await _permissionService.requestAudioPermissions();
    debugPrint('[CALL TRACE] permission check END: status=$permStatus');

    if (permStatus != CallPermissionStatus.granted) {
      final message = _permissionService.getPermissionErrorMessage(callType, permStatus);
      debugPrint('[CALL TRACE] Call failed: Permission not granted ($message)');
      state = state.copyWith(
        status: CallStatus.failed,
        errorMessage: message,
      );
      return false;
    }

    final callId = const Uuid().v4();
    debugPrint('[CALL TRACE] callId generated: $callId');
    // Deterministic single-source-of-truth channel tied directly to call ID
    final defaultChannel = 'call_${callId.replaceAll("-", "")}';
    final effectiveChannel = (AgoraDebugConfig.useTemporaryToken &&
            AgoraDebugConfig.temporaryChannelName.isNotEmpty &&
            AgoraDebugConfig.temporaryChannelName != 'PASTE_CHANNEL_NAME_HERE')
        ? AgoraDebugConfig.temporaryChannelName
        : ((customChannelName != null && customChannelName.isNotEmpty)
            ? customChannelName
            : defaultChannel);

    final call = CallModel(
      id: callId,
      callerId: fbUser.uid,
      callerName: (fbUser.displayName != null && fbUser.displayName!.isNotEmpty)
          ? fbUser.displayName!
          : (currentUser?.name ?? 'Caller'),
      callerPhoto: fbUser.photoURL ?? currentUser?.photoUrl,
      calleeId: targetUser.id,
      calleeName: targetUser.name,
      calleePhoto: targetUser.photoUrl,
      callType: callType,
      status: CallStatus.calling,
      channelName: effectiveChannel,
      startedAt: DateTime.now(),
      direction: CallDirection.outgoing,
    );

    debugPrint('[CALL TRACE] callingService.startCall START (callId: $callId, channel: $effectiveChannel)');
    final result = await _callingService.startCall(call);
    debugPrint('[CALL TRACE] callingService.startCall END: result=$result');
    return result;
  }

  void handleIncomingCall(CallModel call) {
    _callingService.receiveIncomingCall(call);
  }

  void triggerIncomingCallDemo({
    required UserModel caller,
    required CallType callType,
  }) {
    final currentUser = _ref.read(currentUserProvider);
    if (currentUser == null) return;

    final callId = const Uuid().v4();
    final call = CallModel(
      id: callId,
      callerId: caller.id,
      callerName: caller.name,
      callerPhoto: caller.photoUrl,
      calleeId: currentUser.id,
      calleeName: currentUser.name,
      calleePhoto: currentUser.photoUrl,
      callType: callType,
      status: CallStatus.ringing,
      channelName: 'call_${callId.replaceAll("-", "").substring(0, 12)}',
      startedAt: DateTime.now(),
      direction: CallDirection.incoming,
    );

    _callingService.receiveIncomingCall(call);
  }

  Future<bool> acceptCall() async {
    final call = state.call;
    if (call == null) return false;

    final permStatus = call.callType == CallType.video
        ? await _permissionService.requestVideoPermissions()
        : await _permissionService.requestAudioPermissions();

    if (permStatus != CallPermissionStatus.granted) {
      final message = _permissionService.getPermissionErrorMessage(call.callType, permStatus);
      state = state.copyWith(
        status: CallStatus.failed,
        errorMessage: message,
      );
      return false;
    }

    return await _callingService.acceptCall();
  }

  Future<void> rejectCall() async {
    await _callingService.rejectCall();
  }

  Future<void> endCall() async {
    await _callingService.endCall();
  }

  Future<void> toggleMicrophone() async {
    await _callingService.toggleMicrophone();
  }

  Future<void> toggleCamera() async {
    await _callingService.toggleCamera();
  }

  Future<void> switchCamera() async {
    await _callingService.switchCamera();
  }

  Future<void> toggleSpeaker([bool? forceState]) async {
    await _callingService.toggleSpeaker(forceState);
  }

  void connectAgoraForCaller() {
    _callingService.connectAgoraForCaller();
  }

  void connectAgoraForReceiver() {
    _callingService.connectAgoraForReceiver();
  }

  Future<bool> openAppSettings() async {
    return await _permissionService.openAppSettings();
  }

  void resetSession() {
    state = const CallSession();
  }
}

final callControllerProvider =
    StateNotifierProvider<CallController, CallSession>((ref) {
  final callingService = ref.watch(callingServiceProvider);
  final permissionService = ref.watch(permissionServiceProvider);
  return CallController(callingService, permissionService, ref);
});
