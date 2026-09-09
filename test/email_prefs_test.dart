import 'package:flutter_test/flutter_test.dart';
import 'package:gostylens/models/api_responses/email_prefs.dart';

void main() {
  group('EmailPrefs.fromJson', () {
    test('parses camelCase opted-in payload', () {
      final prefs = EmailPrefs.fromJson({
        'marketingOptIn': true,
        'marketingOptInAt': 1710000000000,
        'marketingUnsubscribedAt': null,
      });

      expect(prefs.marketingOptIn, isTrue);
      expect(prefs.marketingOptInAt, 1710000000000);
      expect(prefs.marketingUnsubscribedAt, isNull);
    });

    test('parses missing row as opted out', () {
      final prefs = EmailPrefs.fromJson({
        'marketingOptIn': false,
        'marketingOptInAt': null,
        'marketingUnsubscribedAt': null,
      });

      expect(prefs.marketingOptIn, isFalse);
      expect(prefs.marketingOptInAt, isNull);
      expect(prefs.marketingUnsubscribedAt, isNull);
    });

    test('treats non-true marketingOptIn as false', () {
      expect(
        EmailPrefs.fromJson({'marketingOptIn': 1}).marketingOptIn,
        isFalse,
      );
      expect(EmailPrefs.fromJson({}).marketingOptIn, isFalse);
    });

    test('coerces numeric timestamps from JSON numbers', () {
      final prefs = EmailPrefs.fromJson({
        'marketingOptIn': false,
        'marketingOptInAt': 1710000000000.0,
        'marketingUnsubscribedAt': 1710000001000.0,
      });

      expect(prefs.marketingOptInAt, 1710000000000);
      expect(prefs.marketingUnsubscribedAt, 1710000001000);
    });
  });
}
