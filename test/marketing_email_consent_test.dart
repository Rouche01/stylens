import 'package:flutter_test/flutter_test.dart';
import 'package:gostylens/core/marketing_email/consent.dart';
import 'package:gostylens/models/api_responses/email_prefs.dart';

void main() {
  group('patchValueAfterOnboarding', () {
    test('Yes PATCHes true', () {
      expect(
        MarketingEmailConsent.patchValueAfterOnboarding(accepted: true),
        isTrue,
      );
    });

    test('Not now does not PATCH', () {
      expect(
        MarketingEmailConsent.patchValueAfterOnboarding(accepted: false),
        isNull,
      );
    });
  });

  group('isSoftReaskEligible', () {
    test('null prefs (never written) are eligible', () {
      expect(MarketingEmailConsent.isSoftReaskEligible(null), isTrue);
      expect(
        MarketingEmailConsent.isSoftReaskEligible(EmailPrefs.optedOut),
        isTrue,
      );
    });

    test('opted-in users are not eligible', () {
      expect(
        MarketingEmailConsent.isSoftReaskEligible(
          const EmailPrefs(
            marketingOptIn: true,
            marketingOptInAt: 1,
          ),
        ),
        isFalse,
      );
    });

    test('unsubscribed users are not eligible', () {
      expect(
        MarketingEmailConsent.isSoftReaskEligible(
          const EmailPrefs(
            marketingOptIn: false,
            marketingUnsubscribedAt: 2,
          ),
        ),
        isFalse,
      );
    });
  });
}
