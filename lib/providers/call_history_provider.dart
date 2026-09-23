import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/models/call_history_model.dart';
import '../models/call_model.dart';
import '../services/call_history_service.dart';
import '../services/recent_contacts_service.dart';
import 'auth_provider.dart';
import 'block_provider.dart';

final callHistoryServiceProvider = Provider<CallHistoryService>((ref) {
  return CallHistoryService();
});

/// Real-time Firestore stream of call history documents for current user
final callHistoryStreamProvider =
    StreamProvider.autoDispose<List<CallHistoryModel>>((ref) {
  final currentUser = ref.watch(currentUserProvider);
  if (currentUser == null || currentUser.id.isEmpty) {
    return Stream.value([]);
  }
  final service = ref.watch(callHistoryServiceProvider);
  return service.watchHistory(currentUser.id);
});

class CallHistoryNotifier extends StateNotifier<AsyncValue<List<CallHistoryModel>>> {
  final CallHistoryService _service;
  final Ref _ref;
  StreamSubscription<List<CallHistoryModel>>? _sub;

  CallHistoryNotifier(this._service, this._ref) : super(const AsyncValue.loading()) {
    _initListener();
  }

  void _initListener() {
    final currentUser = _ref.read(currentUserProvider);
    if (currentUser != null && currentUser.id.isNotEmpty) {
      _sub?.cancel();
      _sub = _service.watchHistory(currentUser.id).listen(
        (data) {
          state = AsyncValue.data(data);
        },
        onError: (err, st) {
          state = AsyncValue.error(err, st);
        },
      );
    } else {
      loadHistory();
    }
  }

  Future<void> loadHistory() async {
    state = const AsyncValue.loading();
    try {
      final currentUser = _ref.read(currentUserProvider);
      final userId = currentUser?.id ?? '';
      final list = await _service.getHistoryForUser(userId);
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addCall(CallModel call) async {
    await _service.logCall(call);
    await loadHistory();
  }

  Future<void> deleteHistory(String historyId) async {
    await _service.deleteHistory(historyId);
    final currentList = state.valueOrNull;
    if (currentList != null) {
      state = AsyncValue.data(currentList.where((h) => h.id != historyId).toList());
    }
  }

  Future<void> clearHistory() async {
    final currentUser = _ref.read(currentUserProvider);
    final userId = currentUser?.id ?? '';
    await _service.clearHistoryForUser(userId);
    state = const AsyncValue.data([]);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final callHistoryNotifierProvider =
    StateNotifierProvider.autoDispose<CallHistoryNotifier, AsyncValue<List<CallHistoryModel>>>((ref) {
  ref.watch(currentUserProvider);
  final service = ref.watch(callHistoryServiceProvider);
  return CallHistoryNotifier(service, ref);
});

/// Computes frequently and recently called contacts from completed calls
final frequentContactsProvider = Provider.autoDispose<List<RecentContact>>((ref) {
  final historyAsync = ref.watch(callHistoryStreamProvider);
  final history = historyAsync.valueOrNull ?? [];
  final blockedIds = ref.watch(blockedUserIdsStreamProvider).valueOrNull ?? {};

  final frequent = RecentContactsService.computeFrequentContacts(history);
  return frequent.where((c) => !blockedIds.contains(c.userId)).toList();
});
