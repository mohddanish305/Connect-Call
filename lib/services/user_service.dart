import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

/// Manages Contacts and User Presence via Cloud Firestore 'users' collection
/// with automatic offline cache fallback.
class UserService {
  final FirebaseFirestore? _firestore;

  UserService([FirebaseFirestore? firestore])
      : _firestore = firestore ?? _safeGetFirestore();

  static FirebaseFirestore? _safeGetFirestore() {
    try {
      return FirebaseFirestore.instance;
    } catch (e) {
      debugPrint('[UserService] Firestore not initialized: $e');
      return null;
    }
  }

  /// Retrieve established contacts by explicit ID list from Firestore
  Future<List<UserModel>> getEstablishedContacts(
    List<String> contactIds, {
    String? currentUserId,
  }) async {
    final firestore = _firestore;
    if (firestore == null || contactIds.isEmpty) return <UserModel>[];

    final validIds = contactIds
        .where((id) => id.isNotEmpty && id != currentUserId)
        .toSet()
        .toList();
    if (validIds.isEmpty) return <UserModel>[];

    final List<UserModel> results = [];
    for (var i = 0; i < validIds.length; i += 30) {
      final chunk = validIds.sublist(
        i,
        (i + 30 > validIds.length) ? validIds.length : i + 30,
      );
      try {
        final query = await firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get(const GetOptions(source: Source.serverAndCache))
            .timeout(const Duration(seconds: 5));

        for (final doc in query.docs) {
          final data = doc.data();
          if (data.isNotEmpty) {
            results.add(UserModel.fromMap(data));
          }
        }
      } catch (e) {
        debugPrint('[UserService] getEstablishedContacts chunk error: $e');
      }
    }

    return results;
  }

  /// Get contacts list (scoped strictly to provided contactIds; empty by default)
  Future<List<UserModel>> getContacts({
    List<String>? contactIds,
    String? currentUserId,
  }) async {
    if (contactIds == null || contactIds.isEmpty) {
      return <UserModel>[];
    }
    return getEstablishedContacts(contactIds, currentUserId: currentUserId);
  }

  /// Real-time stream of established contacts with live online/offline presence
  Stream<List<UserModel>> streamEstablishedContacts(
    List<String> contactIds, {
    String? currentUserId,
  }) {
    final firestore = _firestore;
    if (firestore == null || contactIds.isEmpty) {
      return Stream.value(<UserModel>[]);
    }

    final validIds = contactIds
        .where((id) => id.isNotEmpty && id != currentUserId)
        .toSet()
        .toList();
    if (validIds.isEmpty) {
      return Stream.value(<UserModel>[]);
    }

    // Stream up to top 30 established contacts for live online status
    final topIds = validIds.take(30).toList();
    return firestore
        .collection('users')
        .where(FieldPath.documentId, whereIn: topIds)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => UserModel.fromMap(doc.data()))
              .where((u) => currentUserId == null || u.id != currentUserId)
              .toList();
        })
        .handleError((e) {
          debugPrint('[UserService] Stream established contacts error: $e');
          return <UserModel>[];
        });
  }

  /// Deprecated: streamContacts delegates to empty stream if no contactIds are provided
  Stream<List<UserModel>> streamContacts({
    List<String>? contactIds,
    String? currentUserId,
  }) {
    if (contactIds == null || contactIds.isEmpty) {
      return Stream.value(<UserModel>[]);
    }
    return streamEstablishedContacts(contactIds, currentUserId: currentUserId);
  }

  /// Targeted search for users by name or email (minimum 2 characters required).
  /// Enforces privacy: no full collection streaming, self is excluded, blocked users excluded.
  Future<List<UserModel>> searchUsers(
    String query, {
    required String currentUserId,
    Set<String>? blockedUserIds,
  }) async {
    final firestore = _firestore;
    final trimmed = query.trim();
    if (firestore == null || trimmed.length < 2) return <UserModel>[];

    final blocked = blockedUserIds ?? const <String>{};
    final Map<String, UserModel> results = {};

    try {
      final isEmail = trimmed.contains('@');
      if (isEmail) {
        final snap = await firestore
            .collection('users')
            .where('email', isEqualTo: trimmed.toLowerCase())
            .limit(10)
            .get()
            .timeout(const Duration(seconds: 5));

        for (final doc in snap.docs) {
          final data = doc.data();
          if (data.isNotEmpty) {
            final user = UserModel.fromMap(data);
            if (user.id != currentUserId && !blocked.contains(user.id)) {
              results[user.id] = user;
            }
          }
        }
      } else {
        final queriesToTry = <String>{trimmed};
        if (trimmed.isNotEmpty) {
          final capitalized = trimmed[0].toUpperCase() +
              (trimmed.length > 1 ? trimmed.substring(1) : '');
          queriesToTry.add(capitalized);
          final lower = trimmed.toLowerCase();
          queriesToTry.add(lower);
        }

        for (final q in queriesToTry) {
          final snap = await firestore
              .collection('users')
              .where('name', isGreaterThanOrEqualTo: q)
              .where('name', isLessThanOrEqualTo: '$q\uf8ff')
              .limit(15)
              .get()
              .timeout(const Duration(seconds: 5));

          for (final doc in snap.docs) {
            final data = doc.data();
            if (data.isNotEmpty) {
              final user = UserModel.fromMap(data);
              if (user.id != currentUserId && !blocked.contains(user.id)) {
                results[user.id] = user;
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[UserService] searchUsers notice: $e');
    }

    return results.values.toList();
  }

  /// Search contacts delegates to searchUsers
  Future<List<UserModel>> searchContacts(
    String query, {
    String? currentUserId,
    Set<String>? blockedUserIds,
  }) async {
    if (query.trim().length < 2) return <UserModel>[];
    return searchUsers(
      query,
      currentUserId: currentUserId ?? '',
      blockedUserIds: blockedUserIds,
    );
  }

  /// Synchronize current user profile to Firestore
  Future<void> syncUserProfile(UserModel user) async {
    final firestore = _firestore;
    if (firestore == null) return;

    try {
      final data = <String, dynamic>{
        'id': user.id,
        'uid': user.id,
        'name': user.name,
        'displayName': user.name,
        'email': user.email,
        'phone': user.phone,
        'photoUrl': user.photoUrl,
        'isOnline': user.isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      };

      await firestore
          .collection('users')
          .doc(user.id)
          .set(data, SetOptions(merge: true));

      debugPrint('[UserService] Synchronized user profile to Firestore: ${user.name}');
    } catch (e) {
      debugPrint('[UserService] Error syncing user profile: $e');
    }
  }

  /// Update online/offline presence status for a user
  Future<void> setUserPresence(String userId, bool isOnline) async {
    final firestore = _firestore;
    if (firestore == null || userId.isEmpty) return;

    try {
      await firestore.collection('users').doc(userId).update({
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      });
      debugPrint('[UserService] Updated presence for $userId: isOnline=$isOnline');
    } catch (e) {
      debugPrint('[UserService] Notice updating presence: $e');
    }
  }

  /// Retrieve a specific user by ID
  Future<UserModel?> getUserById(String id) async {
    final firestore = _firestore;
    if (firestore != null && id.isNotEmpty) {
      try {
        final doc = await firestore
            .collection('users')
            .doc(id)
            .get()
            .timeout(const Duration(seconds: 5));
        if (doc.exists && doc.data() != null) {
          return UserModel.fromMap(doc.data()!);
        }
      } catch (e) {
        debugPrint('[UserService] getUserById notice: $e');
      }
    }
    return null;
  }
}
