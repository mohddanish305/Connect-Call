import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';
import 'auth_provider.dart';
import 'block_provider.dart';
import 'call_history_provider.dart';

final userServiceProvider = Provider<UserService>((ref) {
  return UserService();
});

final searchQueryProvider = StateProvider<String>((ref) => '');

/// Derives established contact IDs strictly from the current user's call history
final establishedContactIdsProvider = Provider.autoDispose<List<String>>((ref) {
  final historyAsync = ref.watch(callHistoryStreamProvider);
  final history = historyAsync.valueOrNull ?? [];
  final currentUser = ref.watch(currentUserProvider);
  if (currentUser == null || currentUser.id.isEmpty) return <String>[];

  final Set<String> contactIds = {};
  for (final call in history) {
    if (call.otherUserId.isNotEmpty && call.otherUserId != currentUser.id) {
      contactIds.add(call.otherUserId);
    }
  }
  return contactIds.toList();
});

/// Stream of established contacts with real-time online/offline presence from Firestore
final contactsStreamProvider = StreamProvider.autoDispose<List<UserModel>>((ref) {
  final userService = ref.watch(userServiceProvider);
  final currentUser = ref.watch(currentUserProvider);
  final contactIds = ref.watch(establishedContactIdsProvider);

  if (currentUser == null || contactIds.isEmpty) {
    return Stream.value(<UserModel>[]);
  }

  return userService.streamEstablishedContacts(
    contactIds,
    currentUserId: currentUser.id,
  );
});

final contactsListProvider = FutureProvider.autoDispose<List<UserModel>>((ref) async {
  final userService = ref.watch(userServiceProvider);
  final currentUser = ref.watch(currentUserProvider);
  final contactIds = ref.watch(establishedContactIdsProvider);

  if (currentUser == null || contactIds.isEmpty) {
    return <UserModel>[];
  }

  return await userService.getEstablishedContacts(
    contactIds,
    currentUserId: currentUser.id,
  );
});

/// Search query results provider: executes targeted search only when query >= 2 chars
final userSearchResultsProvider = FutureProvider.autoDispose<List<UserModel>>((ref) async {
  final query = ref.watch(searchQueryProvider).trim();
  if (query.length < 2) return <UserModel>[];

  final userService = ref.watch(userServiceProvider);
  final currentUser = ref.watch(currentUserProvider);
  final blockedIds = ref.watch(blockedUserIdsStreamProvider).valueOrNull ?? {};

  if (currentUser == null) return <UserModel>[];

  return await userService.searchUsers(
    query,
    currentUserId: currentUser.id,
    blockedUserIds: blockedIds,
  );
});

/// Filtered contacts provider:
/// - If query is empty: returns established contacts with live presence
/// - If query is 1 character: filters locally within established contacts
/// - If query >= 2 characters: returns targeted search results (merged with any matching established contacts)
/// Never exposes full database, never exposes self, never exposes blocked users.
final filteredContactsProvider = Provider.autoDispose<AsyncValue<List<UserModel>>>((ref) {
  final query = ref.watch(searchQueryProvider).trim();
  final blockedIds = ref.watch(blockedUserIdsStreamProvider).valueOrNull ?? {};
  final currentUser = ref.watch(currentUserProvider);

  if (currentUser == null) {
    return const AsyncValue.data(<UserModel>[]);
  }

  // 1. Default / Empty search query: show established contacts with live status
  if (query.isEmpty) {
    final streamAsync = ref.watch(contactsStreamProvider);
    final contactsAsync = streamAsync.hasValue ? streamAsync : ref.watch(contactsListProvider);
    return contactsAsync.whenData((contacts) {
      return contacts
          .where((u) => !blockedIds.contains(u.id) && u.id != currentUser.id)
          .toList();
    });
  }

  // 2. Query < 2 chars: filter locally within established contacts
  if (query.length < 2) {
    final streamAsync = ref.watch(contactsStreamProvider);
    final contactsAsync = streamAsync.hasValue ? streamAsync : ref.watch(contactsListProvider);
    final lower = query.toLowerCase();
    return contactsAsync.whenData((contacts) {
      return contacts.where((u) {
        if (blockedIds.contains(u.id) || u.id == currentUser.id) return false;
        final nameMatches = u.name.toLowerCase().contains(lower);
        final emailMatches = u.email.toLowerCase().contains(lower);
        final phoneMatches = u.phone.replaceAll(' ', '').contains(lower);
        return nameMatches || emailMatches || phoneMatches;
      }).toList();
    });
  }

  // 3. Query >= 2 chars: perform targeted remote search & merge with matching established
  final searchAsync = ref.watch(userSearchResultsProvider);
  final established = ref.watch(contactsStreamProvider).valueOrNull ?? [];
  final lower = query.toLowerCase();

  return searchAsync.whenData((searchResults) {
    final Map<String, UserModel> merged = {};

    // Established contacts that match query (retaining real-time presence)
    for (final u in established) {
      if (blockedIds.contains(u.id) || u.id == currentUser.id) continue;
      if (u.name.toLowerCase().contains(lower) ||
          u.email.toLowerCase().contains(lower) ||
          u.phone.replaceAll(' ', '').contains(lower)) {
        merged[u.id] = u;
      }
    }

    // Remote directory search results
    for (final u in searchResults) {
      if (!blockedIds.contains(u.id) && u.id != currentUser.id) {
        merged.putIfAbsent(u.id, () => u);
      }
    }

    return merged.values.toList();
  });
});
