import 'package:flutter_test/flutter_test.dart';
import 'package:gostylens/models/api_responses/subscription.dart';
import 'package:gostylens/widgets/capture_page_header.dart';

Subscription _subscription({
  String tier = 'free',
  String status = 'active',
  int sessionCountLimit = 5,
}) {
  return Subscription(
    id: 'sub-1',
    userId: 'user-1',
    tier: tier,
    status: status,
    hasReachedLimit: false,
    limits: SubscriptionLimits(
      sessionCountLimit: sessionCountLimit,
      messagePerSessionLimit: 20,
      imagePerSessionLimit: 10,
    ),
  );
}

void main() {
  test('hides upgrade until the subscription fetch has settled', () {
    expect(
      shouldShowCaptureUpgrade(
        subscriptionResolved: false,
        userHasCorePlan: false,
        subscription: _subscription(),
      ),
      isFalse,
    );
  });

  test('shows upgrade for a resolved limited free plan', () {
    expect(
      shouldShowCaptureUpgrade(
        subscriptionResolved: true,
        userHasCorePlan: false,
        subscription: _subscription(),
      ),
      isTrue,
    );
  });

  test('hides upgrade when sessions are unlimited', () {
    expect(
      shouldShowCaptureUpgrade(
        subscriptionResolved: true,
        userHasCorePlan: false,
        subscription: _subscription(sessionCountLimit: -1),
      ),
      isFalse,
    );
  });

  test('hides upgrade for an active core plan', () {
    expect(
      shouldShowCaptureUpgrade(
        subscriptionResolved: true,
        userHasCorePlan: true,
        subscription: _subscription(tier: 'core'),
      ),
      isFalse,
    );
  });

  test('hides upgrade when subscription is missing', () {
    expect(
      shouldShowCaptureUpgrade(
        subscriptionResolved: true,
        userHasCorePlan: false,
        subscription: null,
      ),
      isFalse,
    );
  });
}
