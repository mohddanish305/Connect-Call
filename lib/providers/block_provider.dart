import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/block_service.dart';
import 'auth_provider.dart';

final blockServiceProvider = Provider<BlockService>((ref) {
  return BlockService(ref: ref);
});

final blockedUserIdsStreamProvider = StreamProvider.autoDispose<Set<String>>((ref) {
  ref.watch(firebaseAuthStateProvider);
  final blockService = ref.watch(blockServiceProvider);
  User? authUser;
  try {
    authUser = FirebaseAuth.instance.currentUser;
  } catch (_) {}
  if (authUser == null) return Stream.value({});
  return blockService.streamBlockedUserIds(authUser.uid);
});

/// Direct boolean provider to check if a specific user is blocked by current user
final isUserBlockedProvider = Provider.autoDispose.family<bool, String>((ref, targetUid) {
  final blockedIds = ref.watch(blockedUserIdsStreamProvider).valueOrNull ?? {};
  return blockedIds.contains(targetUid);
});
