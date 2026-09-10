import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/call_model.dart';
import '../models/call_session.dart';
import '../models/user_model.dart';
import '../services/calling_service.dart';
import '../services/permission_service.dart';
import 'auth_provider.dart';
import 'call_history_provider.dart';

final permissionServiceProvider = Provider<PermissionService>((ref) {
  return PermissionService();
});

final callingServiceProvider = Provider<CallingService>((ref) {
  final historyService = ref.watch(callHistoryServiceProvider);
  final service = CallingService(historyService);
  ref.onDispose(() {
    service.dispose();
  });
  return service;
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
  }

  Future<bool> startCall({
    required UserModel targetUser,
    required CallType callType,
  }) async {
    final currentUser = _ref.read(currentUserProvider);
    if (currentUser == null) return false;

    // Check permissions
    final permStatus = callType == CallType.video
        ? await _permissionService.requestVideoPermissions()
        : await _permissionService.requestAudioPermissions();

    if (permStatus != CallPermissionStatus.granted) {
      state = state.copyWith(
        status: CallStatus.failed,
        errorMessage: permStatus == CallPermissionStatus.permanentlyDenied
            ? 'Permission permanently denied. Please enable microphone/camera in app settings.'
            : 'Permission denied. Microphone and camera access are required to place calls.',
      );
      return false;
    }

    final call = CallModel(
      id: const Uuid().v4(),
      callerId: currentUser.id,
      callerName: currentUser.name,
      callerPhoto: currentUser.photoUrl,
      calleeId: targetUser.id,
      calleeName: targetUser.name,
      calleePhoto: targetUser.photoUrl,
      callType: callType,
      status: CallStatus.calling,
      startedAt: DateTime.now(),
      direction: CallDirection.outgoing,
    );

    await _callingService.startCall(call);
    return true;
  }

  void triggerIncomingCallDemo({
    required UserModel caller,
    required CallType callType,
  }) {
    final currentUser = _ref.read(currentUserProvider);
    if (currentUser == null) return;

    final call = CallModel(
      id: const Uuid().v4(),
      callerId: caller.id,
      callerName: caller.name,
      callerPhoto: caller.photoUrl,
      calleeId: currentUser.id,
      calleeName: currentUser.name,
      calleePhoto: currentUser.photoUrl,
      callType: callType,
      status: CallStatus.ringing,
      startedAt: DateTime.now(),
      direction: CallDirection.incoming,
    );

    _callingService.receiveIncomingCall(call);
  }

  Future<void> acceptCall() async {
    final call = state.call;
    if (call == null) return;

    final permStatus = call.callType == CallType.video
        ? await _permissionService.requestVideoPermissions()
        : await _permissionService.requestAudioPermissions();

    if (permStatus != CallPermissionStatus.granted) {
      state = state.copyWith(
        status: CallStatus.failed,
        errorMessage: 'Microphone and camera permissions are required to accept the call.',
      );
      return;
    }

    await _callingService.acceptCall();
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
