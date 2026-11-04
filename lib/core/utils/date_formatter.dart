import 'package:intl/intl.dart';

class DateFormatter {
  static String formatMessageTime(DateTime dateTime) {
    return DateFormat('h:mm a').format(dateTime);
  }

  static String formatChatListTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0 && now.day == dateTime.day) {
      return DateFormat('h:mm a').format(dateTime);
    } else if (difference.inDays < 7) {
      return DateFormat('EEE').format(dateTime);
    } else {
      return DateFormat('MMM d').format(dateTime);
    }
  }

  static String formatCallDuration(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  static String formatLastSeen(DateTime? lastSeen) {
    if (lastSeen == null) return 'Offline';
    final now = DateTime.now();
    final difference = now.difference(lastSeen);

    if (difference.inMinutes < 1) {
      return 'Last seen just now';
    } else if (difference.inMinutes < 60) {
      return 'Last seen ${difference.inMinutes}m ago';
    } else if (difference.inHours < 24 && now.day == lastSeen.day) {
      return 'Last seen at ${DateFormat('h:mm a').format(lastSeen)}';
    } else if (difference.inDays == 1) {
      return 'Last seen yesterday at ${DateFormat('h:mm a').format(lastSeen)}';
    } else {
      return 'Last seen on ${DateFormat('MMM d').format(lastSeen)}';
    }
  }
}
