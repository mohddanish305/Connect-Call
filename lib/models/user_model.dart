import 'package:intl/intl.dart';

/// User profile model for ConnectCall.
/// Supports both Firestore documents and local caching with backwards compatibility.
class UserModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String? photoUrl;
  final bool isOnline;
  final DateTime lastSeen;
  final DateTime? createdAt;
  final String? fcmToken;

  // Compatibility aliases
  String get uid => id;
  String get displayName => name;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone = '',
    this.photoUrl,
    this.isOnline = false,
    required this.lastSeen,
    this.createdAt,
    this.fcmToken,
  });

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? photoUrl,
    bool? isOnline,
    DateTime? lastSeen,
    DateTime? createdAt,
    String? fcmToken,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      photoUrl: photoUrl ?? this.photoUrl,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      createdAt: createdAt ?? this.createdAt,
      fcmToken: fcmToken ?? this.fcmToken,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uid': id,
      'name': name,
      'displayName': name,
      'email': email,
      'phone': phone,
      'photoUrl': photoUrl,
      'isOnline': isOnline,
      'lastSeen': lastSeen.toIso8601String(),
      'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
      'fcmToken': fcmToken,
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

  factory UserModel.fromMap(Map<String, dynamic> map) {
    final resolvedId = map['id'] ?? map['uid'] ?? '';
    final resolvedName = map['name'] ?? map['displayName'] ?? '';

    return UserModel(
      id: resolvedId.toString(),
      name: resolvedName.toString(),
      email: (map['email'] ?? '').toString(),
      phone: (map['phone'] ?? '').toString(),
      photoUrl: map['photoUrl'] ?? map['photoURL'] ?? map['avatar'],
      isOnline: map['isOnline'] == true,
      lastSeen: _parseDateTime(map['lastSeen']) ?? DateTime.now(),
      createdAt: _parseDateTime(map['createdAt']) ?? _parseDateTime(map['lastSeen']) ?? DateTime.now(),
      fcmToken: map['fcmToken']?.toString(),
    );
  }

  /// User-friendly presence status description
  String get lastSeenFormatted {
    if (isOnline) return 'Online';

    final now = DateTime.now();
    final difference = now.difference(lastSeen);

    if (difference.inMinutes < 1) {
      return 'Last seen just now';
    } else if (difference.inMinutes < 60) {
      return 'Last seen ${difference.inMinutes}m ago';
    } else if (difference.inHours < 24 && now.day == lastSeen.day) {
      return 'Last seen today at ${DateFormat('h:mm a').format(lastSeen)}';
    } else if (difference.inDays < 2) {
      return 'Last seen yesterday at ${DateFormat('h:mm a').format(lastSeen)}';
    } else {
      return 'Last seen ${DateFormat('MMM d').format(lastSeen)}';
    }
  }
}
