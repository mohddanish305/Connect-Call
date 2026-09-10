import 'package:intl/intl.dart';

class DateFormatter {
  DateFormatter._();

  static String formatCallTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final checkDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    final timeString = DateFormat('h:mm a').format(dateTime);

    if (checkDate == today) {
      return 'Today, $timeString';
    } else if (checkDate == yesterday) {
      return 'Yesterday, $timeString';
    } else if (now.difference(dateTime).inDays < 7) {
      final weekday = DateFormat('EEEE').format(dateTime);
      return '$weekday, $timeString';
    } else {
      final date = DateFormat('MMM d').format(dateTime);
      return '$date, $timeString';
    }
  }

  static String formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    final minStr = minutes.toString().padLeft(2, '0');
    final secStr = remainingSeconds.toString().padLeft(2, '0');
    return '$minStr:$secStr';
  }
}
