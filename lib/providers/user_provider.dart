import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';
import 'auth_provider.dart';

final userServiceProvider = Provider<UserService>((ref) {
  final authService = ref.watch(authServiceProvider);
  return UserService(authService);
});

final searchQueryProvider = StateProvider<String>((ref) => '');

final contactsListProvider = FutureProvider.autoDispose<List<UserModel>>((ref) async {
  final userService = ref.watch(userServiceProvider);
  final currentUser = ref.watch(currentUserProvider);
  return await userService.getContacts(currentUserId: currentUser?.id);
});

final filteredContactsProvider = Provider.autoDispose<AsyncValue<List<UserModel>>>((ref) {
  final contactsAsync = ref.watch(contactsListProvider);
  final query = ref.watch(searchQueryProvider).trim().toLowerCase();

  return contactsAsync.whenData((contacts) {
    if (query.isEmpty) return contacts;
    return contacts.where((u) {
      final nameMatches = u.name.toLowerCase().contains(query);
      final emailMatches = u.email.toLowerCase().contains(query);
      final phoneMatches = u.phone.replaceAll(' ', '').contains(query);
      return nameMatches || emailMatches || phoneMatches;
    }).toList();
  });
});
