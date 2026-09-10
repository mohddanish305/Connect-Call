import 'auth_service.dart';
import '../models/user_model.dart';

class UserService {
  final AuthService _authService;

  UserService(this._authService);

  Future<List<UserModel>> getContacts({String? currentUserId}) async {
    final allUsers = await _authService.getAllUsers();
    if (currentUserId == null) return allUsers;
    return allUsers.where((u) => u.id != currentUserId).toList();
  }

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

  Future<UserModel?> getUserById(String id) async {
    final allUsers = await _authService.getAllUsers();
    try {
      return allUsers.firstWhere((u) => u.id == id);
    } catch (_) {
      return null;
    }
  }
}
