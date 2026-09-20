import '../core/models/call_history_model.dart';

class RecentContact {
  final String userId;
  final String name;
  final String? avatar;
  final int callCount;
  final DateTime lastCallTime;
  final CallType lastCallType;

  const RecentContact({
    required this.userId,
    required this.name,
    this.avatar,
    required this.callCount,
    required this.lastCallTime,
    required this.lastCallType,
  });

  String get lastCallTimeFormatted {
    final now = DateTime.now();
    final difference = now.difference(lastCallTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${lastCallTime.day}/${lastCallTime.month}/${lastCallTime.year}';
    }
  }
}

class RecentContactsService {
  /// Computes frequently and recently contacted users based strictly on completed/successful calls.
  static List<RecentContact> computeFrequentContacts(List<CallHistoryModel> history) {
    final Map<String, List<CallHistoryModel>> grouped = {};

    for (final call in history) {
      // Do not count rejected/missed calls as completed successful calls
      if (call.status != CallHistoryStatus.completed) continue;
      if (call.otherUserId.isEmpty) continue;

      grouped.putIfAbsent(call.otherUserId, () => []).add(call);
    }

    final List<RecentContact> results = [];

    for (final entry in grouped.entries) {
      final calls = entry.value;
      calls.sort((a, b) => b.endedAt.compareTo(a.endedAt));
      final latest = calls.first;

      results.add(
        RecentContact(
          userId: entry.key,
          name: latest.otherUserName,
          avatar: latest.otherUserAvatar,
          callCount: calls.length,
          lastCallTime: latest.endedAt,
          lastCallType: latest.callType,
        ),
      );
    }

    // Sort by frequency (callCount descending), then recency (lastCallTime descending)
    results.sort((a, b) {
      final cmp = b.callCount.compareTo(a.callCount);
      if (cmp != 0) return cmp;
      return b.lastCallTime.compareTo(a.lastCallTime);
    });

    return results;
  }
}
