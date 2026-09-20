import 'package:cloud_firestore/cloud_firestore.dart';
import 'call_model.dart' show CallType;

class GroupParticipant {
  final String userId;
  final String name;
  final String? avatar;
  final int agoraUid;
  final bool isMuted;
  final bool isCameraOff;
  final bool hasLeft;
  final String status; // 'invited', 'ringing', 'accepted', 'joined', 'declined', 'left'

  const GroupParticipant({
    required this.userId,
    required this.name,
    this.avatar,
    required this.agoraUid,
    this.isMuted = false,
    this.isCameraOff = false,
    this.hasLeft = false,
    this.status = 'ringing',
  });

  bool get isJoined => status == 'joined';
  bool get isRinging => status == 'ringing' || status == 'invited';
  bool get isDeclined => status == 'declined';

  factory GroupParticipant.fromMap(Map<String, dynamic> map, String userId) {
    return GroupParticipant(
      userId: userId,
      name: map['name'] as String? ?? 'User',
      avatar: map['avatar'] as String?,
      agoraUid: (map['agoraUid'] as num?)?.toInt() ?? 0,
      isMuted: map['isMuted'] as bool? ?? false,
      isCameraOff: map['isCameraOff'] as bool? ?? false,
      hasLeft: map['hasLeft'] as bool? ?? false,
      status: map['status'] as String? ?? (map['hasLeft'] == true ? 'left' : 'ringing'),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'avatar': avatar,
      'agoraUid': agoraUid,
      'isMuted': isMuted,
      'isCameraOff': isCameraOff,
      'hasLeft': hasLeft,
      'status': status,
    };
  }

  GroupParticipant copyWith({
    String? userId,
    String? name,
    String? avatar,
    int? agoraUid,
    bool? isMuted,
    bool? isCameraOff,
    bool? hasLeft,
    String? status,
  }) {
    return GroupParticipant(
      userId: userId ?? this.userId,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      agoraUid: agoraUid ?? this.agoraUid,
      isMuted: isMuted ?? this.isMuted,
      isCameraOff: isCameraOff ?? this.isCameraOff,
      hasLeft: hasLeft ?? this.hasLeft,
      status: status ?? this.status,
    );
  }
}

class GroupCallModel {
  final String id;
  final String title;
  final String hostId;
  final String hostName;
  final List<String> participantIds;
  final Map<String, GroupParticipant> participants;
  final CallType callType;
  final String channelName;
  final bool isActive;
  final DateTime createdAt;

  const GroupCallModel({
    required this.id,
    required this.title,
    required this.hostId,
    required this.hostName,
    required this.participantIds,
    required this.participants,
    required this.callType,
    required this.channelName,
    this.isActive = true,
    required this.createdAt,
  });

  GroupParticipant? getParticipant(String userId) => participants[userId];

  GroupParticipant? getParticipantByAgoraUid(int agoraUid) {
    for (final p in participants.values) {
      if (p.agoraUid == agoraUid) return p;
    }
    return null;
  }

  int get activeParticipantCount =>
      participants.values.where((p) => !p.hasLeft && p.status != 'declined').length;

  factory GroupCallModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final rawParticipants = data['participants'] as Map<String, dynamic>? ?? {};
    final participants = <String, GroupParticipant>{};

    rawParticipants.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        participants[key] = GroupParticipant.fromMap(value, key);
      }
    });

    return GroupCallModel(
      id: doc.id,
      title: data['title'] as String? ?? 'Group Call',
      hostId: data['hostId'] as String? ?? '',
      hostName: data['hostName'] as String? ?? 'Host',
      participantIds: List<String>.from(data['participantIds'] as List? ?? []),
      participants: participants,
      callType: data['callType'] == 'audio' ? CallType.audio : CallType.video,
      channelName: data['channelName'] as String? ?? 'group_${doc.id}',
      isActive: data['isActive'] as bool? ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'hostId': hostId,
      'hostName': hostName,
      'participantIds': participantIds,
      'participants': participants.map((key, value) => MapEntry(key, value.toMap())),
      'callType': callType == CallType.audio ? 'audio' : 'video',
      'channelName': channelName,
      'isActive': isActive,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
