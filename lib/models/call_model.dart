enum CallType { audio, video }

enum CallStatus {
  calling,
  ringing,
  connected,
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
  final DateTime startedAt;
  final DateTime? endedAt;
  final int duration; // in seconds
  final CallDirection direction;
  final bool isMissed;

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
    required this.startedAt,
    this.endedAt,
    this.duration = 0,
    required this.direction,
    this.isMissed = false,
  });

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
    DateTime? startedAt,
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
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      duration: duration ?? this.duration,
      direction: direction ?? this.direction,
      isMissed: isMissed ?? this.isMissed,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'callerId': callerId,
      'callerName': callerName,
      'callerPhoto': callerPhoto,
      'calleeId': calleeId,
      'calleeName': calleeName,
      'calleePhoto': calleePhoto,
      'callType': callType.name,
      'status': status.name,
      'startedAt': startedAt.toIso8601String(),
      'endedAt': endedAt?.toIso8601String(),
      'duration': duration,
      'direction': direction.name,
      'isMissed': isMissed,
    };
  }

  factory CallModel.fromMap(Map<String, dynamic> map) {
    return CallModel(
      id: map['id'] ?? '',
      callerId: map['callerId'] ?? '',
      callerName: map['callerName'] ?? '',
      callerPhoto: map['callerPhoto'],
      calleeId: map['calleeId'] ?? '',
      calleeName: map['calleeName'] ?? '',
      calleePhoto: map['calleePhoto'],
      callType: map['callType'] == 'video' ? CallType.video : CallType.audio,
      status: CallStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => CallStatus.ended,
      ),
      startedAt: map['startedAt'] != null
          ? DateTime.tryParse(map['startedAt']) ?? DateTime.now()
          : DateTime.now(),
      endedAt: map['endedAt'] != null ? DateTime.tryParse(map['endedAt']) : null,
      duration: map['duration'] ?? 0,
      direction: CallDirection.values.firstWhere(
        (e) => e.name == map['direction'],
        orElse: () => CallDirection.outgoing,
      ),
      isMissed: map['isMissed'] ?? false,
    );
  }
}
