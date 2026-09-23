import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../core/services/agora_token_client.dart';
import '../models/call_model.dart';

/// Handles Cloud Firestore call document signaling for 1-to-1 audio and video calls.
/// Implements server timestamps, atomic transactions, busy state checks, and duplicate call protection.
class CallSignalingService {
  final FirebaseFirestore? _firestore;

  CallSignalingService([FirebaseFirestore? firestore])
      : _firestore = firestore ?? _safeGetFirestore();

  static FirebaseFirestore? _safeGetFirestore() {
    try {
      return FirebaseFirestore.instance;
    } catch (e) {
      debugPrint('[CallSignalingService] Firestore not initialized: $e');
      return null;
    }
  }

  bool get isAvailable => _firestore != null;

  /// Active status values that indicate a user is currently engaged in a call
  static const List<String> activeStatuses = [
    'calling',
    'ringing',
    'accepted',
    'connecting',
    'connected',
    'inCall',
    'reconnecting',
  ];

  /// Terminal status values that indicate a call has ended
  static const List<String> terminalStatuses = [
    'ended',
    'rejected',
    'missed',
    'failed',
  ];

  /// Check whether the user is currently involved in an active call.
  /// Enforces Section 16 Busy State and Section 24 Duplicate Event Protection.
  Future<CallModel?> getActiveCallForUser(String userId) async {
    final firestore = _firestore;
    final currentAuthUid = FirebaseAuth.instance.currentUser?.uid;
    if (firestore == null || userId.isEmpty) return null;

    debugPrint('[CALL TRACE] Firestore getActiveCallForUser START: $userId (auth: $currentAuthUid)');

    // Security rule compatibility: An authenticated user can only query calls where they are a participant.
    if (currentAuthUid != null && userId != currentAuthUid) {
      // Check if there is an active call between this authenticated user and the target user
      try {
        debugPrint('[CALL TRACE] pairQuery START');
        final pairQuery = await firestore
            .collection('calls')
            .where('callerId', isEqualTo: currentAuthUid)
            .where('receiverId', isEqualTo: userId)
            .where('status', whereIn: activeStatuses)
            .limit(1)
            .get()
            .timeout(const Duration(seconds: 4));
        debugPrint('[CALL TRACE] pairQuery END: docs count = ${pairQuery.docs.length}');

        if (pairQuery.docs.isNotEmpty) {
          return CallModel.fromMap(pairQuery.docs.first.data());
        }
      } on TimeoutException catch (e) {
        debugPrint('[CALL TRACE] pairQuery TIMEOUT: $e');
        throw const CallingServiceException(
          'Unable to reach calling service. Check your connection and try again.',
          statusCode: 503,
          canRetry: true,
        );
      } on FirebaseException catch (e) {
        debugPrint('[CALL TRACE] pairQuery FirebaseException: ${e.code} ${e.message}');
        if (e.code == 'unavailable' || e.code == 'deadline-exceeded') {
          throw const CallingServiceException(
            'Unable to reach calling service. Check your connection and try again.',
            statusCode: 503,
            canRetry: true,
          );
        }
        rethrow;
      } catch (e) {
        debugPrint('[CALL TRACE] pairQuery EXCEPTION: $e');
        rethrow;
      }
      return null;
    }

    try {
      debugPrint('[CALL TRACE] callerQuery START (callerId == $userId)');
      final callerQuery = await firestore
          .collection('calls')
          .where('callerId', isEqualTo: userId)
          .where('status', whereIn: activeStatuses)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 4));
      debugPrint('[CALL TRACE] callerQuery END: docs count = ${callerQuery.docs.length}');

      if (callerQuery.docs.isNotEmpty) {
        return CallModel.fromMap(callerQuery.docs.first.data());
      }

      debugPrint('[CALL TRACE] receiverQuery START (receiverId == $userId)');
      final receiverQuery = await firestore
          .collection('calls')
          .where('receiverId', isEqualTo: userId)
          .where('status', whereIn: activeStatuses)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 4));
      debugPrint('[CALL TRACE] receiverQuery END: docs count = ${receiverQuery.docs.length}');

      if (receiverQuery.docs.isNotEmpty) {
        return CallModel.fromMap(receiverQuery.docs.first.data());
      }
    } on TimeoutException catch (e) {
      debugPrint('[CALL TRACE] active call query TIMEOUT: $e');
      throw const CallingServiceException(
        'Unable to reach calling service. Check your connection and try again.',
        statusCode: 503,
        canRetry: true,
      );
    } on FirebaseException catch (e) {
      debugPrint('[CALL TRACE] active call query FirebaseException: ${e.code} ${e.message}');
      if (e.code == 'unavailable' || e.code == 'deadline-exceeded') {
        throw const CallingServiceException(
          'Unable to reach calling service. Check your connection and try again.',
          statusCode: 503,
          canRetry: true,
        );
      }
      rethrow;
    } catch (e) {
      debugPrint('[CALL TRACE] active call query EXCEPTION: $e');
      rethrow;
    }
    debugPrint('[CALL TRACE] Firestore getActiveCallForUser END (no active call)');
    return null;
  }

  /// Check whether a specific user is currently busy on another active call
  Future<bool> isUserBusy(String userId) async {
    final active = await getActiveCallForUser(userId);
    return active != null;
  }

  /// Create a new call document in 'calls/{callId}' with status 'ringing' and server timestamp.
  /// Section 21 & 22: Firestore call creation must succeed before Agora channel is joined.
  Future<void> createCall(CallModel call) async {
    final firestore = _firestore;
    if (firestore == null) {
      throw Exception('Database service is unavailable. Unable to start the call.');
    }

    try {
      final docData = <String, dynamic>{
        'callId': call.id,
        'id': call.id,
        'callerId': call.callerId,
        'receiverId': call.receiverId,
        'calleeId': call.receiverId,
        'callerName': call.callerName,
        'callerAvatar': call.callerAvatar,
        'callerPhoto': call.callerAvatar,
        'receiverName': call.receiverName,
        'calleeName': call.receiverName,
        'receiverAvatar': call.receiverAvatar,
        'calleePhoto': call.receiverAvatar,
        'callType': call.callType.name,
        'channelName': call.channelName,
        'status': CallStatus.ringing.name,
        'createdAt': FieldValue.serverTimestamp(),
        'startedAt': FieldValue.serverTimestamp(),
        'acceptedAt': null,
        'endedAt': null,
        'duration': null,
      };

      debugPrint('[CALL TRACE] firestore.doc(${call.id}).set START');
      await firestore
          .collection('calls')
          .doc(call.id)
          .set(docData, SetOptions(merge: true))
          .timeout(const Duration(seconds: 4));
      debugPrint('[CALL TRACE] firestore.doc(${call.id}).set END');

      debugPrint('[CallSignalingService] Call document created: ${call.id} (status: ringing, type: ${call.callType.name})');
    } on TimeoutException catch (e) {
      debugPrint('[CALL TRACE] firestore.doc(${call.id}).set TIMEOUT: $e');
      throw const CallingServiceException(
        'Unable to reach calling service. Check your connection and try again.',
        statusCode: 503,
        canRetry: true,
      );
    } on FirebaseException catch (e) {
      debugPrint('[CALL TRACE] firestore.doc(${call.id}).set FirebaseException: ${e.code} ${e.message}');
      if (e.code == 'unavailable' || e.code == 'deadline-exceeded') {
        throw const CallingServiceException(
          'Unable to reach calling service. Check your connection and try again.',
          statusCode: 503,
          canRetry: true,
        );
      }
      throw CallingServiceException(
        e.message ?? 'Unable to start the call. Please check your network connection.',
        statusCode: 500,
        canRetry: true,
      );
    } catch (e) {
      debugPrint('[CALL TRACE] firestore.doc(${call.id}).set EXCEPTION: $e');
      debugPrint('[CallSignalingService] Error creating call document: $e');
      throw const CallingServiceException(
        'Unable to start the call. Please check your network connection.',
        statusCode: 500,
        canRetry: true,
      );
    }
  }

  /// Atomically accept an incoming call using a Firestore transaction.
  /// Prevents race conditions where caller already ended, rejected, or call timed out.
  Future<bool> acceptCallSafely(String callId) async {
    final firestore = _firestore;
    if (firestore == null) return false;

    debugPrint('[ACCEPT DEBUG] 04 canAccept check START');
    try {
      final docRef = firestore.collection('calls').doc(callId);
      return await firestore.runTransaction<bool>((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists || snapshot.data() == null) {
          debugPrint('[CallSignalingService] Accept failed: call $callId does not exist.');
          debugPrint('[ACCEPT DEBUG] 05 canAccept check END result=false (snapshot does not exist)');
          return false;
        }

        final currentStatus = snapshot.data()?['status'] as String?;
        // Allow ringing, calling, and already accepted (idempotent re-entry)
        final canAccept = currentStatus == CallStatus.ringing.name ||
            currentStatus == CallStatus.calling.name ||
            currentStatus == CallStatus.accepted.name;
        debugPrint('[ACCEPT DEBUG] 05 canAccept check END result=$canAccept (status in Firestore: $currentStatus)');

        if (!canAccept) {
          debugPrint('[CallSignalingService] Cannot accept call $callId. Status is already terminal: $currentStatus');
          return false;
        }

        debugPrint('[ACCEPT DEBUG] 06 update accepted START');
        if (currentStatus != CallStatus.accepted.name) {
          debugPrint(
            '[CALL STATUS]\n'
            'callId=$callId\n'
            'oldStatus=${currentStatus ?? "none"}\n'
            'newStatus=accepted\n'
            'source=CallSignalingService.acceptCallSafely',
          );
          transaction.update(docRef, {
            'status': CallStatus.accepted.name,
            'acceptedAt': FieldValue.serverTimestamp(),
          });
        }
        debugPrint('[ACCEPT DEBUG] 07 update accepted END');
        return true;
      });
    } catch (e) {
      debugPrint('[CallSignalingService] Error accepting call transaction $callId: $e');
      debugPrint('[ACCEPT DEBUG] 05 canAccept check END result=false (transaction exception: $e)');
      // Resilient fallback: direct update if document exists and is not in terminal state
      try {
        final docRef = firestore.collection('calls').doc(callId);
        final docSnap = await docRef.get().timeout(const Duration(seconds: 3));
        if (docSnap.exists) {
          final curStatus = docSnap.data()?['status'] as String?;
          if (curStatus == CallStatus.ringing.name ||
              curStatus == CallStatus.calling.name ||
              curStatus == CallStatus.accepted.name) {
            if (curStatus != CallStatus.accepted.name) {
              debugPrint(
                '[CALL STATUS]\n'
                'callId=$callId\n'
                'oldStatus=${curStatus ?? "none"}\n'
                'newStatus=accepted\n'
                'source=CallSignalingService.acceptCallSafely.fallback',
              );
              await docRef.update({
                'status': CallStatus.accepted.name,
                'acceptedAt': FieldValue.serverTimestamp(),
              });
            }
            debugPrint('[CallSignalingService] Fallback accept direct update succeeded.');
            return true;
          }
        }
      } catch (fallbackErr) {
        debugPrint('[CallSignalingService] Fallback accept update error: $fallbackErr');
      }
      return false;
    }
  }

  /// Atomically reject an incoming call using a Firestore transaction.
  /// Ensures rejection only updates if call is still ringing.
  Future<bool> rejectCallSafely(String callId) async {
    final firestore = _firestore;
    if (firestore == null) return false;

    try {
      final docRef = firestore.collection('calls').doc(callId);
      return await firestore.runTransaction<bool>((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists || snapshot.data() == null) {
          return false;
        }

        final currentStatus = snapshot.data()?['status'] as String?;
        if (terminalStatuses.contains(currentStatus)) {
          return false;
        }

        debugPrint(
          '[CALL STATUS]\n'
          'callId=$callId\n'
          'oldStatus=${currentStatus ?? "none"}\n'
          'newStatus=rejected\n'
          'source=CallSignalingService.rejectCallSafely',
        );
        transaction.update(docRef, {
          'status': CallStatus.rejected.name,
          'endedAt': FieldValue.serverTimestamp(),
        });
        return true;
      });
    } catch (e) {
      debugPrint('[CallSignalingService] Error rejecting call transaction $callId: $e');
      return false;
    }
  }

  /// Update status of a call document (accepted, rejected, ended, missed, reconnecting, etc.)
  /// Protects terminal states from being accidentally overwritten.
  Future<void> updateCallStatus(
    String callId,
    CallStatus status, {
    int? duration,
  }) async {
    final firestore = _firestore;
    if (firestore == null) return;

    try {
      final docRef = firestore.collection('calls').doc(callId);
      final doc = await docRef.get().timeout(const Duration(seconds: 4));
      if (!doc.exists) return;

      final currentStatus = doc.data()?['status'] as String?;
      // If already in a terminal status and requested status is not terminal, ignore
      if (terminalStatuses.contains(currentStatus) &&
          !terminalStatuses.contains(status.name)) {
        debugPrint('[CallSignalingService] Ignoring status update to ${status.name} because call $callId is already $currentStatus');
        return;
      }

      debugPrint('[CALL TRACE 13] Firestore call status update (callId: $callId, status: ${status.name})');
      debugPrint(
        '[CALL STATUS]\n'
        'callId=$callId\n'
        'oldStatus=${currentStatus ?? "none"}\n'
        'newStatus=${status.name}\n'
        'source=CallSignalingService.updateCallStatus',
      );

      final data = <String, dynamic>{
        'status': status.name,
      };
      if (duration != null) {
        data['duration'] = duration;
      }
      if (status == CallStatus.accepted) {
        data['acceptedAt'] = FieldValue.serverTimestamp();
      } else if (status == CallStatus.rejected ||
          status == CallStatus.ended ||
          status == CallStatus.missed ||
          status == CallStatus.failed) {
        data['endedAt'] = FieldValue.serverTimestamp();
      }

      await docRef.update(data).timeout(const Duration(seconds: 4));
      debugPrint('[CallSignalingService] Call document updated: $callId -> status: ${status.name}');
    } catch (e) {
      debugPrint('[CallSignalingService] Error updating call status: $e');
    }
  }

  /// Stream updates for a specific call session document
  Stream<CallModel?> streamCall(String callId) {
    final firestore = _firestore;
    if (firestore == null) {
      return const Stream.empty();
    }

    return firestore
        .collection('calls')
        .doc(callId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) return null;
      return CallModel.fromMap(snapshot.data()!);
    }).handleError((e) {
      debugPrint('[CallSignalingService] Error streaming call $callId: $e');
      return null;
    });
  }

  /// Stream incoming calls directed to the current user with status 'ringing'
  Stream<List<CallModel>> streamIncomingCalls(String currentUserId) {
    final firestore = _firestore;
    if (firestore == null || currentUserId.isEmpty) {
      return const Stream.empty();
    }

    return firestore
        .collection('calls')
        .where('receiverId', isEqualTo: currentUserId)
        .where('status', isEqualTo: CallStatus.ringing.name)
        .snapshots()
        .map((snapshot) {
      final now = DateTime.now();
      return snapshot.docs
          .map((doc) => CallModel.fromMap(doc.data()))
          .where((call) {
            // Drop stale calls older than 45 seconds so they never hijack HomeScreen
            final diff = now.difference(call.startedAt).inSeconds;
            return diff < 45;
          })
          .toList();
    }).handleError((e) {
      debugPrint('[CallSignalingService] Error streaming incoming calls for user $currentUserId: $e');
      return <CallModel>[];
    });
  }
}
