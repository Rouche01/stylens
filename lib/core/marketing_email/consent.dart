import 'package:gostylens/models/api_responses/email_prefs.dart';

/// Decisions for marketing email consent (separate from [User] prefs API).
class MarketingEmailConsent {
  static const sourceOnboarding = 'onboarding';
  static const sourceProfile = 'profile';
  static const sourcePostFirstTip = 'post_first_tip';

  /// PATCH body after onboarding. `null` means omit the request (Not now).
  static bool? patchValueAfterOnboarding({required bool accepted}) {
    return accepted ? true : null;
  }

  /// Soft re-ask: never opted in and never unsubscribed / explicit opt-out.
  static bool isSoftReaskEligible(EmailPrefs? prefs) {
    final resolved = prefs ?? EmailPrefs.optedOut;
    return !resolved.marketingOptIn && resolved.marketingUnsubscribedAt == null;
  }
}
