import 'package:flutter_test/flutter_test.dart';
import 'package:gostylens/utils/time_utils.dart';

void main() {
  group('formatEpochMillis', () {
    test('returns nullLabel when null', () {
      expect(formatEpochMillis(null), '—');
      expect(formatEpochMillis(null, nullLabel: 'n/a'), 'n/a');
    });

    test('formats millisecond timestamps', () {
      // 2025-01-06 00:00:00 UTC
      expect(formatEpochMillis(1736121600000), 'Jan 6, 2025');
    });
  });

  group('formatEpochSeconds', () {
    test('returns nullLabel when null', () {
      expect(formatEpochSeconds(null), '—');
    });

    test('formats second timestamps', () {
      // Same instant as above, in seconds
      expect(formatEpochSeconds(1736121600), 'Jan 6, 2025');
    });
  });
}
