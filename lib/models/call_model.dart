enum CallType { audio, video }

enum CallStatus {
  calling,
  ringing,
  connecting,
  accepted,
  connected,
  reconnecting,
  inCall,
  ended,
  rejected,
  missed,
  busy,
  failed,
  disconnected,
}

enum CallDirection { incoming, outgoing, missed }

class CallModel {
  final String id;
  final String callerId;
  final String callerName;
  final String? callerPhoto;
  final String calleeId;
  final String calleeName;
  final String? calleePhoto;
  final CallType callType;
  final CallStatus status;
  final String channelName;
  final DateTime startedAt;
  final DateTime? acceptedAt;
  final DateTime? endedAt;
  final int duration; // in seconds
  final CallDirection direction;
  final bool isMissed;

  // Semantic aliases for Firestore specifications
  String get callId => id;
  String get receiverId => calleeId;
  String? get callerAvatar => callerPhoto;
  String get receiverName => calleeName;
  String? get receiverAvatar => calleePhoto;

  const CallModel({
    required this.id,
    required this.callerId,
    required this.callerName,
    this.callerPhoto,
    required this.calleeId,
    required this.calleeName,
    this.calleePhoto,
    required this.callType,
    required this.status,
    String? channelName,
    required this.startedAt,
    this.acceptedAt,
    this.endedAt,
    this.duration = 0,
    required this.direction,
    this.isMissed = false,
  }) : channelName = channelName ?? 'call_$id';

  CallModel copyWith({
    String? id,
    String? callerId,
    String? callerName,
    String? callerPhoto,
    String? calleeId,
    String? calleeName,
    String? calleePhoto,
    CallType? callType,
    CallStatus? status,
    String? channelName,
    DateTime? startedAt,
    DateTime? acceptedAt,
    DateTime? endedAt,
    int? duration,
    CallDirection? direction,
    bool? isMissed,
  }) {
    return CallModel(
      id: id ?? this.id,
      callerId: callerId ?? this.callerId,
      callerName: callerName ?? this.callerName,
      callerPhoto: callerPhoto ?? this.callerPhoto,
      calleeId: calleeId ?? this.calleeId,
      calleeName: calleeName ?? this.calleeName,
      calleePhoto: calleePhoto ?? this.calleePhoto,
      callType: callType ?? this.callType,
      status: status ?? this.status,
      channelName: channelName ?? this.channelName,
      startedAt: startedAt ?? this.startedAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      endedAt: endedAt ?? this.endedAt,
      duration: duration ?? this.duration,
      direction: direction ?? this.direction,
      isMissed: isMissed ?? this.isMissed,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'callId': id,
      'callerId': callerId,
      'callerName': callerName,
      'callerPhoto': callerPhoto,
      'callerAvatar': callerPhoto,
      'calleeId': calleeId,
      'receiverId': calleeId,
      'calleeName': calleeName,
      'receiverName': calleeName,
      'calleePhoto': calleePhoto,
      'receiverAvatar': calleePhoto,
      'callType': callType.name,
      'status': status.name,
      'channelName': channelName,
      'startedAt': startedAt.toIso8601String(),
      'createdAt': startedAt.toIso8601String(),
      'acceptedAt': acceptedAt?.toIso8601String(),
      'endedAt': endedAt?.toIso8601String(),
      'duration': duration,
      'direction': direction.name,
      'isMissed': isMissed,
    };
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    // Support cloud_firestore Timestamp dynamically without hard import dependency
    try {
      final dynamic ts = value;
      if (ts.toDate != null && ts.toDate is Function) {
        return ts.toDate() as DateTime;
      }
    } catch (_) {}
    return null;
  }

  factory CallModel.fromMap(Map<String, dynamic> map) {
    final callerId = map['callerId'] ?? '';
    final calleeId = map['calleeId'] ?? map['receiverId'] ?? '';
    final callId = map['id'] ?? map['callId'] ?? '';

    final rawStarted = _parseDateTime(map['startedAt']) ?? _parseDateTime(map['createdAt']) ?? DateTime.now();
    final rawAccepted = _parseDateTime(map['acceptedAt']);
    final rawEnded = _parseDateTime(map['endedAt']);

    return CallModel(
      id: callId,
      callerId: callerId,
      callerName: map['callerName'] ?? '',
      callerPhoto: map['callerPhoto'] ?? map['callerAvatar'],
      calleeId: calleeId,
      calleeName: map['calleeName'] ?? map['receiverName'] ?? '',
      calleePhoto: map['calleePhoto'] ?? map['receiverAvatar'],
      callType: map['callType'] == 'video' ? CallType.video : CallType.audio,
      status: CallStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => CallStatus.ended,
      ),
      channelName: (map['channelName'] != null && map['channelName'].toString().isNotEmpty)
          ? map['channelName']
          : 'call_${callId.replaceAll("-", "")}',
      startedAt: rawStarted,
      acceptedAt: rawAccepted,
      endedAt: rawEnded,
      duration: map['duration'] is int ? map['duration'] : int.tryParse(map['duration']?.toString() ?? '0') ?? 0,
      direction: CallDirection.values.firstWhere(
        (e) => e.name == map['direction'],
        orElse: () => CallDirection.outgoing,
      ),
      isMissed: map['isMissed'] ?? (map['status'] == 'missed'),
    );
  }
}
