import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/group_call_model.dart';
import '../services/group_call_service.dart';
import 'auth_provider.dart';

final groupCallServiceProvider = Provider<GroupCallService>((ref) {
  final service = GroupCallService();
  ref.onDispose(() {
    service.leaveGroupCall();
  });
  return service;
});

/// Stream of active incoming group calls targeting the current user
final incomingGroupCallsStreamProvider = StreamProvider.autoDispose<List<GroupCallModel>>((ref) {
  final currentUser = ref.watch(currentUserProvider);
  if (currentUser == null) return const Stream.empty();
  final service = ref.watch(groupCallServiceProvider);
  return service.streamIncomingGroupCalls(currentUser.id);
});

class GroupCallNotifier extends StateNotifier<GroupCallSession> {
  final GroupCallService _service;

  GroupCallNotifier(this._service) : super(_service.session) {
    _service.onSessionChanged = (newSession) {
      state = newSession;
    };
  }

  Future<void> toggleMute() => _service.toggleMute();
  Future<void> toggleCamera() => _service.toggleCamera();
  Future<void> switchCamera() => _service.switchCamera();
  Future<void> toggleSpeaker() => _service.toggleSpeaker();
  Future<void> leaveCall() => _service.leaveGroupCall();
}

final groupCallNotifierProvider =
    StateNotifierProvider<GroupCallNotifier, GroupCallSession>((ref) {
  final service = ref.watch(groupCallServiceProvider);
  return GroupCallNotifier(service);
});
