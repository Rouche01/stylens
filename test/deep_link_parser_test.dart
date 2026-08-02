import 'package:flutter_test/flutter_test.dart';
import 'package:gostylens/core/navigation/deep_link/deep_link_destination.dart';
import 'package:gostylens/core/navigation/deep_link/deep_link_parser.dart';
import 'package:gostylens/core/navigation/deep_link/push_notification_types.dart';

void main() {
  final parser = DeepLinkParser();

  group('parseUri', () {
    test('parses paywall and billing hosts', () {
      expect(
        parser.parseUri(Uri.parse('gostylens://paywall'))?.target,
        DeepLinkTarget.paywall,
      );
      expect(
        parser.parseUri(Uri.parse('gostylens://billing'))?.target,
        DeepLinkTarget.billing,
      );
      expect(
        parser.parseUri(Uri.parse('gostylens:/paywall'))?.target,
        DeepLinkTarget.paywall,
      );
    });

    test('parses session id from path', () {
      final destination = parser.parseUri(Uri.parse('gostylens://session/abc'));
      expect(destination?.target, DeepLinkTarget.session);
      expect(destination?.sessionId, 'abc');
    });

    test('coerces numeric session_id query param', () {
      final destination = parser.parseUri(
        Uri.parse('gostylens://open?dest=session&session_id=42'),
      );
      expect(destination?.target, DeepLinkTarget.session);
      expect(destination?.sessionId, '42');
    });

    test('invite-only hosts return null destination', () {
      expect(
        parser.parseUri(Uri.parse('gostylens://invite?code=SUMMER50')),
        isNull,
      );
      expect(
        parser.parseUri(Uri.parse('gostylens://open?dest=invite&code=ABC')),
        isNull,
      );
      expect(
        parser.parseUri(Uri.parse('gostylens:/invite?code=ABC')),
        isNull,
      );
    });
  });

  group('extractInviteCode', () {
    test('reads code query param and normalizes', () {
      expect(
        parser.extractInviteCode(
          Uri.parse('gostylens://invite?code=summer50'),
        ),
        'SUMMER50',
      );
    });

    test('accepts inviteCode alias', () {
      expect(
        parser.extractInviteCode(
          Uri.parse('gostylens://capture?inviteCode=VIP'),
        ),
        'VIP',
      );
    });

    test('reads code from invite path segment', () {
      expect(
        parser.extractInviteCode(Uri.parse('gostylens://invite/promo1')),
        'PROMO1',
      );
    });

    test('returns null when no code present', () {
      expect(
        parser.extractInviteCode(Uri.parse('gostylens://history')),
        isNull,
      );
    });
  });

  group('parsePushData', () {
    test('parses legacy style_advice_ready with numeric session_id', () {
      final destination = parser.parsePushData({
        'type': PushNotificationTypes.styleAdviceReady,
        'session_id': 12345,
      });
      expect(destination.target, DeepLinkTarget.session);
      expect(destination.sessionId, '12345');
    });

    test('parses explicit link to session', () {
      final destination = parser.parsePushData({
        'link': 'gostylens://session/abc',
        'title': 'Advice ready',
      });
      expect(destination.target, DeepLinkTarget.session);
      expect(destination.sessionId, 'abc');
    });

    test('falls back to capture when type and session_id missing', () {
      expect(
        parser.parsePushData({'title': 'Hello'}).target,
        DeepLinkTarget.capture,
      );
    });
  });
}
