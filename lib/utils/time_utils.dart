import 'package:intl/intl.dart';

/// Formats a DateTime into a friendly "time ago" string representation
String formatTimeAgo(DateTime date) {
  final now = DateTime.now();
  final difference = now.difference(date);

  if (difference.inMinutes < 1) {
    return 'Just now';
  } else if (difference.inMinutes < 60) {
    return '${difference.inMinutes}m ago';
  } else if (difference.inHours < 24) {
    return '${difference.inHours}h ago';
  } else if (difference.inDays == 1) {
    return 'Yesterday';
  } else if (difference.inDays < 7) {
    return '${difference.inDays}d ago';
  } else {
    return '${date.day}/${date.month}/${date.year}';
  }
}

const _epochDatePattern = 'MMM d, yyyy';

/// Formats an epoch timestamp in **milliseconds** (e.g. API `trial_ends_at`).
String formatEpochMillis(int? epochMillis, {String nullLabel = '—'}) {
  if (epochMillis == null) return nullLabel;
  return DateFormat(_epochDatePattern).format(
    DateTime.fromMillisecondsSinceEpoch(epochMillis),
  );
}

/// Formats an epoch timestamp in **seconds** (e.g. RevenueCat `current_period_end`).
String formatEpochSeconds(int? epochSeconds, {String nullLabel = '—'}) {
  if (epochSeconds == null) return nullLabel;
  return DateFormat(_epochDatePattern).format(
    DateTime.fromMillisecondsSinceEpoch(epochSeconds * 1000),
  );
}
