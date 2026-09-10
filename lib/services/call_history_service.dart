import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/call_model.dart';

class CallHistoryService {
  static const String _callHistoryKey = 'connectcall_call_history_records';

  // Seed default history matching the PDF assignment wireframes
  static final List<CallModel> defaultHistory = [
    CallModel(
      id: 'hist_1',
      callerId: 'user_1',
      callerName: 'Sarah Johnson',
      callerPhoto: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=200&auto=format&fit=crop&q=80',
      calleeId: 'current_user',
      calleeName: 'You',
      callType: CallType.video,
      status: CallStatus.ended,
      startedAt: DateTime.now().subtract(const Duration(hours: 3)),
      endedAt: DateTime.now().subtract(const Duration(hours: 3)).add(const Duration(minutes: 2, seconds: 35)),
      duration: 155, // 02:35
      direction: CallDirection.incoming,
      isMissed: false,
    ),
    CallModel(
      id: 'hist_2',
      callerId: 'user_2',
      callerName: 'John Smith',
      callerPhoto: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200&auto=format&fit=crop&q=80',
      calleeId: 'current_user',
      calleeName: 'You',
      callType: CallType.audio,
      status: CallStatus.missed,
      startedAt: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
      duration: 0,
      direction: CallDirection.missed,
      isMissed: true,
    ),
    CallModel(
      id: 'hist_3',
      callerId: 'current_user',
      callerName: 'You',
      calleeId: 'user_3',
      calleeName: 'Alex Wilson',
      calleePhoto: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=200&auto=format&fit=crop&q=80',
      callType: CallType.audio,
      status: CallStatus.ended,
      startedAt: DateTime.now().subtract(const Duration(days: 2, hours: 5)),
      endedAt: DateTime.now().subtract(const Duration(days: 2, hours: 5)).add(const Duration(minutes: 5, seconds: 12)),
      duration: 312, // 05:12
      direction: CallDirection.outgoing,
      isMissed: false,
    ),
  ];

  Future<List<CallModel>> getCallHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_callHistoryKey);
    if (jsonStr == null) {
      await saveAll(defaultHistory);
      return defaultHistory;
    }

    try {
      final List decoded = jsonDecode(jsonStr);
      final list = decoded.map((e) => CallModel.fromMap(e as Map<String, dynamic>)).toList();
      list.sort((a, b) => b.startedAt.compareTo(a.startedAt));
      return list;
    } catch (_) {
      return defaultHistory;
    }
  }

  Future<void> logCall(CallModel call) async {
    final history = await getCallHistory();
    // Prepend new call record
    final updated = [call, ...history];
    await saveAll(updated);
  }

  Future<void> saveAll(List<CallModel> calls) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = calls.map((c) => c.toMap()).toList();
    await prefs.setString(_callHistoryKey, jsonEncode(jsonList));
  }

  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_callHistoryKey);
  }
}
