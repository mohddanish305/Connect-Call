import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/call_model.dart' show CallType, CallDirection;
export '../../models/call_model.dart' show CallType, CallDirection;

enum CallHistoryStatus {
  completed,
  missed,
  rejected,
  failed;

  String get displayName {
    switch (this) {
      case CallHistoryStatus.completed:
        return 'Completed';
      case CallHistoryStatus.missed:
        return 'Missed';
      case CallHistoryStatus.rejected:
        return 'Rejected';
      case CallHistoryStatus.failed:
        return 'Failed';
    }
  }
}

class CallHistoryModel {
  final String id;
  final String callerId;
  final String callerName;
  final String? callerAvatar;
  final String receiverId;
  final String receiverName;
  final String? receiverAvatar;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserAvatar;
  final CallType callType;
  final CallDirection direction;
  final CallHistoryStatus status;
  final DateTime startedAt;
  final DateTime? acceptedAt;
  final DateTime endedAt;
  final int durationSeconds;
  final String channelName;

  bool get isMissed => status == CallHistoryStatus.missed;
  String get calleeId => receiverId;
  String get calleeName => receiverName;
  String? get calleePhoto => receiverAvatar;
  String? get callerPhoto => callerAvatar;

  const CallHistoryModel({
    required this.id,
    required this.callerId,
    required this.callerName,
    this.callerAvatar,
    required this.receiverId,
    required this.receiverName,
    this.receiverAvatar,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserAvatar,
    required this.callType,
    required this.direction,
    required this.status,
    required this.startedAt,
    this.acceptedAt,
    required this.endedAt,
    this.durationSeconds = 0,
    required this.channelName,
  });

  /// Factory constructor to parse Firestore document map relative to current authenticated user
  factory CallHistoryModel.fromMap(
    Map<String, dynamic> map, {
    String id = '',
    String? currentUserId,
  }) {
    final callerId = map['callerId'] ?? '';
    final callerName = map['callerName'] ?? 'Unknown Caller';
    final callerAvatar = map['callerAvatar'] ?? map['callerPhoto'];

    final receiverId = map['receiverId'] ?? map['calleeId'] ?? '';
    final receiverName = map['receiverName'] ?? map['calleeName'] ?? 'Unknown User';
    final receiverAvatar = map['receiverAvatar'] ?? map['calleePhoto'];

    // Resolve direction and other user info relative to current user
    final isCaller = currentUserId != null && currentUserId == callerId;
    final direction = isCaller
        ? CallDirection.outgoing
        : (map['direction'] == 'outgoing' && currentUserId == null
            ? CallDirection.outgoing
            : CallDirection.incoming);

    final otherUserId = isCaller ? receiverId : callerId;
    final otherUserName = isCaller ? receiverName : callerName;
    final otherUserAvatar = isCaller ? receiverAvatar : callerAvatar;

    final rawStarted = _parseDateTime(map['startedAt']) ?? _parseDateTime(map['createdAt']) ?? DateTime.now();
    final rawAccepted = _parseDateTime(map['acceptedAt']);
    final rawEnded = _parseDateTime(map['endedAt']) ?? DateTime.now();

    final statusStr = map['status']?.toString() ?? 'completed';
    final status = CallHistoryStatus.values.firstWhere(
      (e) => e.name == statusStr,
      orElse: () {
        if (statusStr == 'inCall' || statusStr == 'connected' || statusStr == 'ended') {
          return CallHistoryStatus.completed;
        }
        return CallHistoryStatus.completed;
      },
    );

    final duration = map['durationSeconds'] is int
        ? map['durationSeconds'] as int
        : (map['duration'] is int ? map['duration'] as int : int.tryParse(map['durationSeconds']?.toString() ?? '0') ?? 0);

    return CallHistoryModel(
      id: id.isNotEmpty ? id : (map['id'] ?? map['callId'] ?? ''),
      callerId: callerId,
      callerName: callerName,
      callerAvatar: callerAvatar,
      receiverId: receiverId,
      receiverName: receiverName,
      receiverAvatar: receiverAvatar,
      otherUserId: otherUserId.isNotEmpty ? otherUserId : (map['otherUserId'] ?? ''),
      otherUserName: otherUserName.isNotEmpty ? otherUserName : (map['otherUserName'] ?? 'User'),
      otherUserAvatar: otherUserAvatar ?? map['otherUserAvatar'],
      callType: map['callType'] == 'video' ? CallType.video : CallType.audio,
      direction: direction,
      status: status,
      startedAt: rawStarted,
      acceptedAt: rawAccepted,
      endedAt: rawEnded,
      durationSeconds: duration,
      channelName: map['channelName'] ?? '',
    );
  }

  factory CallHistoryModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    String? currentUserId,
  }) {
    return CallHistoryModel.fromMap(
      doc.data() ?? {},
      id: doc.id,
      currentUserId: currentUserId,
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    try {
      final dynamic ts = value;
      if (ts.toDate != null && ts.toDate is Function) {
        return ts.toDate() as DateTime;
      }
    } catch (_) {}
    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'callerId': callerId,
      'callerName': callerName,
      'callerAvatar': callerAvatar,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'receiverAvatar': receiverAvatar,
      'callType': callType.name,
      'direction': direction.name,
      'status': status.name,
      'startedAt': startedAt.toIso8601String(),
      'acceptedAt': acceptedAt?.toIso8601String(),
      'endedAt': endedAt.toIso8601String(),
      'durationSeconds': durationSeconds,
      'channelName': channelName,
    };
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'callerId': callerId,
      'callerName': callerName,
      'callerAvatar': callerAvatar,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'receiverAvatar': receiverAvatar,
      'callType': callType.name,
      'status': status.name,
      'startedAt': Timestamp.fromDate(startedAt),
      'acceptedAt': acceptedAt != null ? Timestamp.fromDate(acceptedAt!) : null,
      'endedAt': Timestamp.fromDate(endedAt),
      'durationSeconds': durationSeconds,
      'channelName': channelName,
    };
  }

  CallHistoryModel copyWith({
    String? id,
    String? callerId,
    String? callerName,
    String? callerAvatar,
    String? receiverId,
    String? receiverName,
    String? receiverAvatar,
    String? otherUserId,
    String? otherUserName,
    String? otherUserAvatar,
    CallType? callType,
    CallDirection? direction,
    CallHistoryStatus? status,
    DateTime? startedAt,
    DateTime? acceptedAt,
    DateTime? endedAt,
    int? durationSeconds,
    String? channelName,
  }) {
    return CallHistoryModel(
      id: id ?? this.id,
      callerId: callerId ?? this.callerId,
      callerName: callerName ?? this.callerName,
      callerAvatar: callerAvatar ?? this.callerAvatar,
      receiverId: receiverId ?? this.receiverId,
      receiverName: receiverName ?? this.receiverName,
      receiverAvatar: receiverAvatar ?? this.receiverAvatar,
      otherUserId: otherUserId ?? this.otherUserId,
      otherUserName: otherUserName ?? this.otherUserName,
      otherUserAvatar: otherUserAvatar ?? this.otherUserAvatar,
      callType: callType ?? this.callType,
      direction: direction ?? this.direction,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      endedAt: endedAt ?? this.endedAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      channelName: channelName ?? this.channelName,
    );
  }

  /// Formatted duration string: mm:ss under 1 hour, hh:mm:ss for longer calls.
  /// Returns status name for non-completed calls.
  String get formattedDurationOrStatus {
    if (status != CallHistoryStatus.completed) {
      return status.displayName;
    }
    if (durationSeconds <= 0) {
      return '00:00';
    }
    final hours = durationSeconds ~/ 3600;
    final minutes = (durationSeconds % 3600) ~/ 60;
    final seconds = durationSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }
}
