class UserModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String? photoUrl;
  final bool isOnline;
  final DateTime lastSeen;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone = '',
    this.photoUrl,
    this.isOnline = false,
    required this.lastSeen,
  });

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? photoUrl,
    bool? isOnline,
    DateTime? lastSeen,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      photoUrl: photoUrl ?? this.photoUrl,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'photoUrl': photoUrl,
      'isOnline': isOnline,
      'lastSeen': lastSeen.toIso8601String(),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      photoUrl: map['photoUrl'],
      isOnline: map['isOnline'] ?? false,
      lastSeen: map['lastSeen'] != null
          ? DateTime.tryParse(map['lastSeen']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
