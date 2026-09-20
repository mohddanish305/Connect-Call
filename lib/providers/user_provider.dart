import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';
import 'auth_provider.dart';
import 'block_provider.dart';

final userServiceProvider = Provider<UserService>((ref) {
  final authService = ref.watch(authServiceProvider);
  return UserService(authService);
});

final searchQueryProvider = StateProvider<String>((ref) => '');

/// Stream of real-time contacts with live online/offline presence from Firestore
final contactsStreamProvider = StreamProvider.autoDispose<List<UserModel>>((ref) {
  final userService = ref.watch(userServiceProvider);
  final currentUser = ref.watch(currentUserProvider);
  return userService.streamContacts(currentUserId: currentUser?.id);
});

final contactsListProvider = FutureProvider.autoDispose<List<UserModel>>((ref) async {
  final userService = ref.watch(userServiceProvider);
  final currentUser = ref.watch(currentUserProvider);
  return await userService.getContacts(currentUserId: currentUser?.id);
});

final filteredContactsProvider = Provider.autoDispose<AsyncValue<List<UserModel>>>((ref) {
  // Prefer real-time stream if data is available, otherwise fallback to future
  final streamAsync = ref.watch(contactsStreamProvider);
  final contactsAsync = streamAsync.hasValue ? streamAsync : ref.watch(contactsListProvider);
  final query = ref.watch(searchQueryProvider).trim().toLowerCase();
  final blockedIds = ref.watch(blockedUserIdsStreamProvider).valueOrNull ?? {};

  return contactsAsync.whenData((contacts) {
    // Filter out any user blocked by the current user
    final unblocked = contacts.where((u) => !blockedIds.contains(u.id)).toList();
    if (query.isEmpty) return unblocked;
    return unblocked.where((u) {
      final nameMatches = u.name.toLowerCase().contains(query);
      final emailMatches = u.email.toLowerCase().contains(query);
      final phoneMatches = u.phone.replaceAll(' ', '').contains(query);
      return nameMatches || emailMatches || phoneMatches;
    }).toList();
  });
});
