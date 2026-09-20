import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/call_history_model.dart';
import '../../models/call_model.dart' as legacy_call;

/// Persistent Cloud Firestore service for Call History.
/// Writes to 'callHistory/{callId}' ensuring idempotent records.
class CallHistoryService {
  final FirebaseFirestore? _firestore;
  static const String _localPrefsKey = 'connectcall_call_history_records';

  // In-memory set of call IDs recorded in this app lifecycle to avoid duplicate writes
  final Set<String> _recordedCallIds = {};

  CallHistoryService([FirebaseFirestore? firestore])
      : _firestore = firestore ?? _safeGetFirestore();

  static FirebaseFirestore? _safeGetFirestore() {
    try {
      return FirebaseFirestore.instance;
    } catch (e) {
      debugPrint('[CallHistoryService] Firestore instance not available: $e');
      return null;
    }
  }

  bool get isAvailable => _firestore != null;

  /// Idempotently create or update a call history record using call.id as document ID
  Future<void> createFromCall(
    legacy_call.CallModel call, {
    required CallHistoryStatus status,
    int durationSeconds = 0,
    DateTime? endedAt,
  }) async {
    final historyId = call.id;
    if (historyId.isEmpty) return;

    final finalEndedAt = endedAt ?? call.endedAt ?? DateTime.now();
    final finalDuration = status == CallHistoryStatus.completed
        ? (durationSeconds > 0 ? durationSeconds : call.duration)
        : 0;

    final history = CallHistoryModel(
      id: historyId,
      callerId: call.callerId,
      callerName: call.callerName,
      callerAvatar: call.callerPhoto,
      receiverId: call.calleeId,
      receiverName: call.calleeName,
      receiverAvatar: call.calleePhoto,
      otherUserId: call.calleeId, // default; resolved per viewing user in fromMap
      otherUserName: call.calleeName,
      otherUserAvatar: call.calleePhoto,
      callType: call.callType == legacy_call.CallType.video ? CallType.video : CallType.audio,
      direction: CallDirection.outgoing, // resolved per viewing user in fromMap
      status: status,
      startedAt: call.startedAt,
      acceptedAt: call.acceptedAt,
      endedAt: finalEndedAt,
      durationSeconds: finalDuration,
      channelName: call.channelName,
    );

    await createHistory(history);
  }

  /// Create or update a call history entry idempotently in Firestore
  Future<void> createHistory(CallHistoryModel history) async {
    final firestore = _firestore;
    final historyId = history.id;
    if (historyId.isEmpty) return;

    // Local deduplication check
    if (_recordedCallIds.contains(historyId) && history.status != CallHistoryStatus.completed) {
      debugPrint('[CallHistoryService] Skip duplicate non-completed history creation for $historyId');
      return;
    }
    _recordedCallIds.add(historyId);

    if (firestore != null) {
      try {
        final docRef = firestore.collection('callHistory').doc(historyId);
        try {
          final existingDoc = await docRef.get();
          if (existingDoc.exists) {
            final existingData = existingDoc.data() ?? {};
            final existingStatus = existingData['status']?.toString();
            // Never overwrite a completed call with missed or rejected
            if (existingStatus == 'completed' && history.status != CallHistoryStatus.completed) {
              debugPrint('[CallHistoryService] Call $historyId already recorded as completed. Preserving.');
              return;
            }
          }
        } catch (_) {
          // Document does not exist or read pre-check notice; proceed to set
        }

        await docRef.set(history.toFirestoreMap(), SetOptions(merge: true));
        debugPrint('[CallHistoryService] Successfully saved call history $historyId to Firestore (${history.status.name})');
      } catch (e) {
        debugPrint('[CallHistoryService] Firestore history save notice: $e');
        // Fallback to local storage
        await _saveLocalHistory(history);
      }
    } else {
      await _saveLocalHistory(history);
    }
  }

  /// Real-time stream of call history documents for the authenticated user.
  /// Subscribes to calls where the user is either the caller or the receiver.
  Stream<List<CallHistoryModel>> watchHistory(String userId, {int limit = 50}) {
    final firestore = _firestore;
    if (firestore == null || userId.isEmpty) {
      return Stream.fromFuture(getLocalHistory(userId));
    }

    final controller = StreamController<List<CallHistoryModel>>.broadcast();

    // Query 1: where callerId == userId (in-memory sort avoids composite index requirement)
    final callerQuery = firestore
        .collection('callHistory')
        .where('callerId', isEqualTo: userId)
        .limit(limit);

    // Query 2: where receiverId == userId (in-memory sort avoids composite index requirement)
    final receiverQuery = firestore
        .collection('callHistory')
        .where('receiverId', isEqualTo: userId)
        .limit(limit);

    Map<String, CallHistoryModel> callerMap = {};
    Map<String, CallHistoryModel> receiverMap = {};

    void emitMerged() {
      if (controller.isClosed) return;
      final allMap = <String, CallHistoryModel>{}
        ..addAll(callerMap)
        ..addAll(receiverMap);

      final list = allMap.values.toList()
        ..sort((a, b) => b.endedAt.compareTo(a.endedAt));

      controller.add(list.take(limit).toList());
    }

    StreamSubscription? sub1;
    StreamSubscription? sub2;

    try {
      sub1 = callerQuery.snapshots().listen((snapshot) {
        callerMap = {
          for (final doc in snapshot.docs)
            doc.id: CallHistoryModel.fromFirestore(doc, currentUserId: userId),
        };
        emitMerged();
      }, onError: (e) {
        debugPrint('[CallHistoryService] callerQuery stream error: $e');
        if (!controller.isClosed) controller.addError(e);
      });

      sub2 = receiverQuery.snapshots().listen((snapshot) {
        receiverMap = {
          for (final doc in snapshot.docs)
            doc.id: CallHistoryModel.fromFirestore(doc, currentUserId: userId),
        };
        emitMerged();
      }, onError: (e) {
        debugPrint('[CallHistoryService] receiverQuery stream error: $e');
        if (!controller.isClosed) controller.addError(e);
      });
    } catch (e) {
      debugPrint('[CallHistoryService] Failed to establish history streams: $e');
      if (!controller.isClosed) controller.addError(e);
    }

    controller.onCancel = () {
      sub1?.cancel();
      sub2?.cancel();
    };

    return controller.stream;
  }

  /// One-shot fetch of call history records for the specified user
  Future<List<CallHistoryModel>> getHistoryForUser(String userId, {int limit = 50}) async {
    final firestore = _firestore;
    if (firestore == null || userId.isEmpty) {
      return getLocalHistory(userId);
    }

    try {
      final callerFuture = firestore
          .collection('callHistory')
          .where('callerId', isEqualTo: userId)
          .limit(limit)
          .get();

      final receiverFuture = firestore
          .collection('callHistory')
          .where('receiverId', isEqualTo: userId)
          .limit(limit)
          .get();

      final results = await Future.wait([callerFuture, receiverFuture]);
      final callerDocs = results[0].docs;
      final receiverDocs = results[1].docs;

      final allMap = <String, CallHistoryModel>{};
      for (final doc in callerDocs) {
        allMap[doc.id] = CallHistoryModel.fromFirestore(doc, currentUserId: userId);
      }
      for (final doc in receiverDocs) {
        allMap[doc.id] = CallHistoryModel.fromFirestore(doc, currentUserId: userId);
      }

      final list = allMap.values.toList()
        ..sort((a, b) => b.endedAt.compareTo(a.endedAt));

      return list.take(limit).toList();
    } catch (e) {
      debugPrint('[CallHistoryService] getHistoryForUser error: $e. Falling back to local storage.');
      return getLocalHistory(userId);
    }
  }

  /// Delete a single call history document
  Future<void> deleteHistory(String historyId) async {
    final firestore = _firestore;
    if (firestore != null) {
      try {
        await firestore.collection('callHistory').doc(historyId).delete();
      } catch (e) {
        debugPrint('[CallHistoryService] deleteHistory error: $e');
      }
    }
    await _deleteLocalHistory(historyId);
  }

  /// Clear all call history for the authenticated user
  Future<void> clearHistoryForUser(String userId) async {
    final firestore = _firestore;
    if (firestore != null && userId.isNotEmpty) {
      try {
        final records = await getHistoryForUser(userId, limit: 100);
        final batch = firestore.batch();
        for (final r in records) {
          batch.delete(firestore.collection('callHistory').doc(r.id));
        }
        await batch.commit();
      } catch (e) {
        debugPrint('[CallHistoryService] clearHistoryForUser error: $e');
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_localPrefsKey);
  }

  // ===============================================================
  // Local SharedPreferences Fallback & Legacy Compatibility
  // ===============================================================

  Future<void> _saveLocalHistory(CallHistoryModel history) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_localPrefsKey);
    List<Map<String, dynamic>> list = [];
    if (jsonStr != null) {
      try {
        final decoded = jsonDecode(jsonStr) as List;
        list = decoded.cast<Map<String, dynamic>>();
      } catch (_) {}
    }
    list.removeWhere((item) => item['id'] == history.id);
    list.insert(0, history.toMap());
    await prefs.setString(_localPrefsKey, jsonEncode(list.take(100).toList()));
  }

  Future<List<CallHistoryModel>> getLocalHistory(String currentUserId) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_localPrefsKey);
    if (jsonStr == null) return [];
    try {
      final decoded = jsonDecode(jsonStr) as List;
      return decoded
          .map((item) => CallHistoryModel.fromMap(item as Map<String, dynamic>, currentUserId: currentUserId))
          .toList()
        ..sort((a, b) => b.endedAt.compareTo(a.endedAt));
    } catch (_) {
      return [];
    }
  }

  Future<void> _deleteLocalHistory(String historyId) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_localPrefsKey);
    if (jsonStr == null) return;
    try {
      final decoded = jsonDecode(jsonStr) as List;
      final list = decoded.cast<Map<String, dynamic>>()
        ..removeWhere((item) => item['id'] == historyId);
      await prefs.setString(_localPrefsKey, jsonEncode(list));
    } catch (_) {}
  }

  // Backward compatibility methods for existing callers
  Future<List<legacy_call.CallModel>> getCallHistory() async {
    final list = await getLocalHistory('');
    return list.map((h) => legacy_call.CallModel(
      id: h.id,
      callerId: h.callerId,
      callerName: h.callerName,
      callerPhoto: h.callerAvatar,
      calleeId: h.receiverId,
      calleeName: h.receiverName,
      calleePhoto: h.receiverAvatar,
      callType: h.callType == CallType.video ? legacy_call.CallType.video : legacy_call.CallType.audio,
      status: h.status == CallHistoryStatus.completed
          ? legacy_call.CallStatus.ended
          : (h.status == CallHistoryStatus.missed
              ? legacy_call.CallStatus.missed
              : (h.status == CallHistoryStatus.rejected
                  ? legacy_call.CallStatus.rejected
                  : legacy_call.CallStatus.failed)),
      startedAt: h.startedAt,
      acceptedAt: h.acceptedAt,
      endedAt: h.endedAt,
      duration: h.durationSeconds,
      direction: h.direction == CallDirection.outgoing ? legacy_call.CallDirection.outgoing : legacy_call.CallDirection.incoming,
      isMissed: h.status == CallHistoryStatus.missed,
    )).toList();
  }

  Future<void> logCall(legacy_call.CallModel call) async {
    final status = call.isMissed
        ? CallHistoryStatus.missed
        : (call.status == legacy_call.CallStatus.rejected
            ? CallHistoryStatus.rejected
            : (call.status == legacy_call.CallStatus.failed
                ? CallHistoryStatus.failed
                : CallHistoryStatus.completed));
    await createFromCall(call, status: status, durationSeconds: call.duration);
  }

  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_localPrefsKey);
  }
}
