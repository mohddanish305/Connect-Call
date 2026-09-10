import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/call_model.dart';
import '../services/call_history_service.dart';

final callHistoryServiceProvider = Provider<CallHistoryService>((ref) {
  return CallHistoryService();
});

class CallHistoryNotifier extends StateNotifier<AsyncValue<List<CallModel>>> {
  final CallHistoryService _service;

  CallHistoryNotifier(this._service) : super(const AsyncValue.loading()) {
    loadHistory();
  }

  Future<void> loadHistory() async {
    state = const AsyncValue.loading();
    try {
      final list = await _service.getCallHistory();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addCall(CallModel call) async {
    await _service.logCall(call);
    await loadHistory();
  }

  Future<void> clearHistory() async {
    await _service.clearHistory();
    state = const AsyncValue.data([]);
  }
}

final callHistoryNotifierProvider =
    StateNotifierProvider<CallHistoryNotifier, AsyncValue<List<CallModel>>>((ref) {
  final service = ref.watch(callHistoryServiceProvider);
  return CallHistoryNotifier(service);
});
