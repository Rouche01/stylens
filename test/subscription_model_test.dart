import 'package:flutter_test/flutter_test.dart';
import 'package:gostylens/models/api_responses/subscription.dart';

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
}
