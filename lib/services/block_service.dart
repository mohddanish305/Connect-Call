import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/block_provider.dart';
import '../providers/call_history_provider.dart';
import '../providers/user_provider.dart';

/// BlockService manages user blocking and unblocking.
/// Structure: users/{currentUserUid}/blockedUsers/{targetUserUid}
class BlockService {
  final FirebaseFirestore _firestore;
  final Ref? _ref;

  BlockService({FirebaseFirestore? firestore, Ref? ref})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _ref = ref;

  /// Block a user
  Future<void> blockUser(
    String targetUid, {
    String? targetName,
    String? currentUserId,
  }) async {
    final authUser = FirebaseAuth.instance.currentUser;
    final currentUid = (currentUserId != null && currentUserId.isNotEmpty)
        ? currentUserId
        : authUser?.uid;

    if (currentUid == null || currentUid.isEmpty) {
      debugPrint('[BLOCK DEBUG]\ncurrentUid=null\ntargetUid=$targetUid\naction=block\nresult=failure_no_auth');
      throw Exception('No authenticated user available to perform block');
    }

    if (targetUid.isEmpty) {
      debugPrint('[BLOCK DEBUG]\ncurrentUid=$currentUid\ntargetUid=empty\naction=block\nresult=failure_empty_target');
      throw Exception('Target user ID cannot be empty');
    }

    if (currentUid == targetUid) {
      debugPrint('[BLOCK DEBUG]\ncurrentUid=$currentUid\ntargetUid=$targetUid\naction=block\nresult=failure_self_block');
      throw Exception('You cannot block yourself');
    }

    debugPrint('[BLOCK DEBUG]\ncurrentUid=$currentUid\ntargetUid=$targetUid\naction=block\nresult=attempt');

    try {
      await _firestore
          .collection('users')
          .doc(currentUid)
          .collection('blockedUsers')
          .doc(targetUid)
          .set({
        'blockedUid': targetUid,
        'blockedName': targetName ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint('[BLOCK DEBUG]\ncurrentUid=$currentUid\ntargetUid=$targetUid\naction=block\nresult=success');

      _invalidateProviders();
    } catch (e) {
      debugPrint('[BLOCK DEBUG]\ncurrentUid=$currentUid\ntargetUid=$targetUid\naction=block\nresult=failure: $e');
      rethrow;
    }
  }

  /// Unblock a user
  Future<void> unblockUser(
    String targetUid, {
    String? currentUserId,
  }) async {
    final authUser = FirebaseAuth.instance.currentUser;
    final currentUid = (currentUserId != null && currentUserId.isNotEmpty)
        ? currentUserId
        : authUser?.uid;

    if (currentUid == null || currentUid.isEmpty) {
      debugPrint('[BLOCK DEBUG]\ncurrentUid=null\ntargetUid=$targetUid\naction=unblock\nresult=failure_no_auth');
      throw Exception('No authenticated user available to perform unblock');
    }

    if (targetUid.isEmpty) return;

    debugPrint('[BLOCK DEBUG]\ncurrentUid=$currentUid\ntargetUid=$targetUid\naction=unblock\nresult=attempt');

    try {
      await _firestore
          .collection('users')
          .doc(currentUid)
          .collection('blockedUsers')
          .doc(targetUid)
          .delete();

      debugPrint('[BLOCK DEBUG]\ncurrentUid=$currentUid\ntargetUid=$targetUid\naction=unblock\nresult=success');

      _invalidateProviders();
    } catch (e) {
      debugPrint('[BLOCK DEBUG]\ncurrentUid=$currentUid\ntargetUid=$targetUid\naction=unblock\nresult=failure: $e');
      rethrow;
    }
  }

  /// Check if current user has blocked target user
  Future<bool> isUserBlocked({
    required String currentUserId,
    required String targetUserId,
  }) async {
    if (currentUserId.isEmpty || targetUserId.isEmpty) return false;

    try {
      final doc = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('blockedUsers')
          .doc(targetUserId)
          .get();
      return doc.exists;
    } catch (e) {
      debugPrint('[BlockService] Error checking block status: $e');
      return false;
    }
  }

  /// Check if target user has blocked current user
  Future<bool> isBlockedByTarget({
    required String currentUserId,
    required String targetUserId,
  }) async {
    if (currentUserId.isEmpty || targetUserId.isEmpty) return false;

    try {
      final doc = await _firestore
          .collection('users')
          .doc(targetUserId)
          .collection('blockedUsers')
          .doc(currentUserId)
          .get();
      return doc.exists;
    } catch (e) {
      debugPrint('[BlockService] Notice checking target block status: $e');
      return false;
    }
  }

  /// Stream of blocked user IDs for current user
  Stream<Set<String>> streamBlockedUserIds(String currentUserId) {
    if (currentUserId.isEmpty) return Stream.value({});

    return _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('blockedUsers')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((d) => d.id).toSet();
    }).handleError((e) {
      debugPrint('[BlockService] Error streaming blocked users: $e');
      return <String>{};
    });
  }

  /// Invalidate all providers affected by block/unblock
  void _invalidateProviders() {
    final ref = _ref;
    if (ref != null) {
      try {
        ref.invalidate(blockedUserIdsStreamProvider);
        ref.invalidate(contactsStreamProvider);
        ref.invalidate(contactsListProvider);
        ref.invalidate(filteredContactsProvider);
        ref.invalidate(frequentContactsProvider);
      } catch (e) {
        debugPrint('[BlockService] Notice invalidating providers: $e');
      }
    }
  }
}
