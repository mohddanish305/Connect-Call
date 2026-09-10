import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/user_model.dart';

class AuthService {
  static const String _userSessionKey = 'connectcall_active_user_session';
  static const String _registeredUsersKey = 'connectcall_registered_users';

  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;

  // Initial demo users matching the assignment PDF wireframes
  static final List<UserModel> defaultUsers = [
    UserModel(
      id: 'user_1',
      name: 'Sarah Johnson',
      email: 'sarah.johnson@connectcall.io',
      phone: '+1 555-0192',
      photoUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=200&auto=format&fit=crop&q=80',
      isOnline: true,
      lastSeen: DateTime.now(),
    ),
    UserModel(
      id: 'user_2',
      name: 'John Smith',
      email: 'john.smith@connectcall.io',
      phone: '+1 555-0143',
      photoUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200&auto=format&fit=crop&q=80',
      isOnline: false,
      lastSeen: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    UserModel(
      id: 'user_3',
      name: 'Alex Wilson',
      email: 'alex.wilson@connectcall.io',
      phone: '+1 555-0188',
      photoUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=200&auto=format&fit=crop&q=80',
      isOnline: true,
      lastSeen: DateTime.now(),
    ),
    UserModel(
      id: 'user_4',
      name: 'Emily Davis',
      email: 'emily.davis@connectcall.io',
      phone: '+1 555-0167',
      photoUrl: 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=200&auto=format&fit=crop&q=80',
      isOnline: true,
      lastSeen: DateTime.now(),
    ),
    UserModel(
      id: 'user_5',
      name: 'Michael Brown',
      email: 'michael.brown@connectcall.io',
      phone: '+1 555-0112',
      photoUrl: 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=200&auto=format&fit=crop&q=80',
      isOnline: false,
      lastSeen: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    // Check if initial users are seeded
    if (!prefs.containsKey(_registeredUsersKey)) {
      final jsonList = defaultUsers.map((u) => u.toMap()).toList();
      await prefs.setString(_registeredUsersKey, jsonEncode(jsonList));
    }

    // Restore user session if available
    final sessionString = prefs.getString(_userSessionKey);
    if (sessionString != null) {
      try {
        final map = jsonDecode(sessionString) as Map<String, dynamic>;
        _currentUser = UserModel.fromMap(map);
      } catch (_) {
        _currentUser = null;
      }
    }
  }

  Future<List<UserModel>> getAllUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_registeredUsersKey);
    if (jsonStr == null) return defaultUsers;

    try {
      final List decoded = jsonDecode(jsonStr);
      return decoded.map((e) => UserModel.fromMap(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return defaultUsers;
    }
  }

  Future<UserModel> signIn({
    required String emailOrPhone,
    required String password,
  }) async {
    if (emailOrPhone.trim().isEmpty || password.trim().isEmpty) {
      throw Exception('Please enter your email/phone and password.');
    }

    if (password.length < 6) {
      throw Exception('Password must be at least 6 characters.');
    }

    final users = await getAllUsers();
    final cleanInput = emailOrPhone.trim().toLowerCase();

    // Look for existing user
    UserModel? foundUser;
    for (final u in users) {
      if (u.email.toLowerCase() == cleanInput || u.phone.replaceAll(' ', '') == cleanInput.replaceAll(' ', '')) {
        foundUser = u;
        break;
      }
    }

    // If user not found, create a demo user with this email/phone so login always works seamlessly
    if (foundUser == null) {
      final namePart = emailOrPhone.contains('@')
          ? emailOrPhone.split('@').first
          : 'User ${emailOrPhone.substring(emailOrPhone.length > 4 ? emailOrPhone.length - 4 : 0)}';
      final formattedName = namePart.substring(0, 1).toUpperCase() + namePart.substring(1);

      foundUser = UserModel(
        id: const Uuid().v4(),
        name: formattedName,
        email: emailOrPhone.contains('@') ? emailOrPhone : '$emailOrPhone@connectcall.io',
        phone: !emailOrPhone.contains('@') ? emailOrPhone : '',
        photoUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200&auto=format&fit=crop&q=80',
        isOnline: true,
        lastSeen: DateTime.now(),
      );

      final updatedList = [...users, foundUser];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_registeredUsersKey, jsonEncode(updatedList.map((e) => e.toMap()).toList()));
    } else {
      foundUser = foundUser.copyWith(isOnline: true, lastSeen: DateTime.now());
    }

    _currentUser = foundUser;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userSessionKey, jsonEncode(foundUser.toMap()));
    return foundUser;
  }

  Future<UserModel> signUp({
    required String name,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    if (name.trim().isEmpty) {
      throw Exception('Please enter your full name.');
    }
    if (!email.contains('@') || !email.contains('.')) {
      throw Exception('Please enter a valid email address.');
    }
    if (password.length < 6) {
      throw Exception('Password must be at least 6 characters long.');
    }
    if (password != confirmPassword) {
      throw Exception('Passwords do not match.');
    }

    final users = await getAllUsers();
    if (users.any((u) => u.email.toLowerCase() == email.trim().toLowerCase())) {
      throw Exception('An account with this email already exists.');
    }

    final newUser = UserModel(
      id: const Uuid().v4(),
      name: name.trim(),
      email: email.trim(),
      photoUrl: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=200&auto=format&fit=crop&q=80',
      isOnline: true,
      lastSeen: DateTime.now(),
    );

    final updatedList = [...users, newUser];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_registeredUsersKey, jsonEncode(updatedList.map((e) => e.toMap()).toList()));

    _currentUser = newUser;
    await prefs.setString(_userSessionKey, jsonEncode(newUser.toMap()));
    return newUser;
  }

  Future<void> signOut() async {
    if (_currentUser != null) {
      // Mark as offline in user list
      final users = await getAllUsers();
      final updatedList = users.map((u) {
        if (u.id == _currentUser!.id) {
          return u.copyWith(isOnline: false, lastSeen: DateTime.now());
        }
        return u;
      }).toList();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_registeredUsersKey, jsonEncode(updatedList.map((e) => e.toMap()).toList()));
      await prefs.remove(_userSessionKey);
    }
    _currentUser = null;
  }

  Future<UserModel> updateProfile({required String name, String? photoUrl}) async {
    if (_currentUser == null) throw Exception('No active session.');

    final updatedUser = _currentUser!.copyWith(
      name: name.trim().isNotEmpty ? name.trim() : _currentUser!.name,
      photoUrl: photoUrl ?? _currentUser!.photoUrl,
    );

    final users = await getAllUsers();
    final updatedList = users.map((u) => u.id == updatedUser.id ? updatedUser : u).toList();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_registeredUsersKey, jsonEncode(updatedList.map((e) => e.toMap()).toList()));
    await prefs.setString(_userSessionKey, jsonEncode(updatedUser.toMap()));

    _currentUser = updatedUser;
    return updatedUser;
  }
}
