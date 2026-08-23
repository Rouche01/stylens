import 'package:flutter_test/flutter_test.dart';
import 'package:gostylens/models/api_responses/subscription.dart';

Subscription _subscription({
  String tier = 'free',
  String status = 'active',
  int? sessionUsage,
  int sessionCountLimit = 5,
}) {
  return Subscription(
    id: 'sub-1',
    userId: 'user-1',
    tier: tier,
    status: status,
    hasReachedLimit: false,
    sessionUsage: sessionUsage,
    limits: SubscriptionLimits(
      sessionCountLimit: sessionCountLimit,
      messagePerSessionLimit: 20,
      imagePerSessionLimit: 10,
    ),
  );
}

void main() {
  test('Subscription.fromJson parses trial and period fields', () {
    final sub = Subscription.fromJson({
      'id': 'sub-1',
      'user_id': 'user-1',
      'tier': 'free',
      'status': 'active',
      'has_reached_limit': 0,
      'in_trial': true,
      'trial_ends_at': 1000,
      'period_start': 500,
      'session_usage': 2,
      'limits': {
        'session_count_limit': -1,
        'message_per_session_limit': 20,
        'image_per_session_limit': 10,
      },
    });

    expect(sub.inTrial, isTrue);
    expect(sub.trialEndsAt, 1000);
    expect(sub.periodStart, 500);
    expect(sub.sessionUsage, 2);
    expect(sub.limits?.sessionCountLimit, -1);
  });

  group('session usage helpers', () {
    test('unlimited when session_count_limit is -1', () {
      final sub = _subscription(sessionUsage: 2, sessionCountLimit: -1);

      expect(sub.hasUnlimitedSessions, isTrue);
      expect(sub.sessionsUsed, 2);
      expect(sub.sessionsRemaining, isNull);
      expect(sub.sessionUsageProgress, isNull);
    });

    test('unlimited for active Core tier', () {
      final sub = _subscription(
        tier: 'core',
        sessionUsage: 10,
        sessionCountLimit: 5,
      );

      expect(sub.hasUnlimitedSessions, isTrue);
      expect(sub.sessionsRemaining, isNull);
      expect(sub.sessionUsageProgress, isNull);
    });

    test('mid-usage reports remaining of limit and progress', () {
      final sub = _subscription(sessionUsage: 3, sessionCountLimit: 5);

      expect(sub.hasUnlimitedSessions, isFalse);
      expect(sub.sessionsUsed, 3);
      expect(sub.sessionsRemaining, 2);
      expect(sub.sessionUsageProgress, closeTo(0.6, 1e-9));
    });

    test('over-limit clamps remaining to 0 and progress to 1', () {
      final sub = _subscription(sessionUsage: 7, sessionCountLimit: 5);

      expect(sub.sessionsRemaining, 0);
      expect(sub.sessionUsageProgress, 1.0);
    });

    test('null sessionUsage treats used as 0', () {
      final sub = _subscription(sessionUsage: null, sessionCountLimit: 5);

      expect(sub.sessionsUsed, 0);
      expect(sub.sessionsRemaining, 5);
      expect(sub.sessionUsageProgress, 0.0);
    });
  });
}
