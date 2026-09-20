import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import 'auth_service.dart';

/// Manages Contacts and User Presence via Cloud Firestore 'users' collection
/// with automatic offline cache fallback.
class UserService {
  final AuthService _authService;
  final FirebaseFirestore? _firestore;

  UserService(this._authService, [FirebaseFirestore? firestore])
      : _firestore = firestore ?? _safeGetFirestore();

  static FirebaseFirestore? _safeGetFirestore() {
    try {
      return FirebaseFirestore.instance;
    } catch (e) {
      debugPrint('[UserService] Firestore not initialized: $e');
      return null;
    }
  }

  /// Get contacts list from Firestore, falling back to local storage if offline
  Future<List<UserModel>> getContacts({String? currentUserId}) async {
    final firestore = _firestore;
    if (firestore != null) {
      try {
        final query = await firestore
            .collection('users')
            .limit(50)
            .get(const GetOptions(source: Source.serverAndCache))
            .timeout(const Duration(seconds: 4));

        if (query.docs.isNotEmpty) {
          final users = query.docs
              .map((doc) => UserModel.fromMap(doc.data()))
              .where((u) => currentUserId == null || u.id != currentUserId)
              .toList();

          return users;
        }
      } catch (e) {
        debugPrint('[UserService] Firestore getContacts fallback to local: $e');
      }
    }

    // Fallback to local cached users
    final allUsers = await _authService.getAllUsers();
    if (currentUserId == null) return allUsers;
    return allUsers.where((u) => u.id != currentUserId).toList();
  }

  /// Real-time stream of all contacts from Firestore
  Stream<List<UserModel>> streamContacts({String? currentUserId}) {
    final firestore = _firestore;
    if (firestore == null) {
      return Stream.fromFuture(getContacts(currentUserId: currentUserId));
    }

    return firestore.collection('users').snapshots().map((snapshot) {
      if (snapshot.docs.isEmpty) return <UserModel>[];

      return snapshot.docs
          .map((doc) => UserModel.fromMap(doc.data()))
          .where((u) => currentUserId == null || u.id != currentUserId)
          .toList();
    }).handleError((e) {
      debugPrint('[UserService] Stream contacts notice: $e');
      return <UserModel>[];
    });
  }

  /// Search contacts by name, email, or phone
  Future<List<UserModel>> searchContacts(String query, {String? currentUserId}) async {
    final contacts = await getContacts(currentUserId: currentUserId);
    if (query.trim().isEmpty) return contacts;

    final lowerQuery = query.trim().toLowerCase();
    return contacts.where((u) {
      final nameMatches = u.name.toLowerCase().contains(lowerQuery);
      final emailMatches = u.email.toLowerCase().contains(lowerQuery);
      final phoneMatches = u.phone.replaceAll(' ', '').contains(lowerQuery);
      return nameMatches || emailMatches || phoneMatches;
    }).toList();
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
    if (firestore != null) {
      try {
        final doc = await firestore.collection('users').doc(id).get();
        if (doc.exists && doc.data() != null) {
          return UserModel.fromMap(doc.data()!);
        }
      } catch (_) {}
    }

    final allUsers = await _authService.getAllUsers();
    try {
      return allUsers.firstWhere((u) => u.id == id);
    } catch (_) {
      return null;
    }
  }
}
