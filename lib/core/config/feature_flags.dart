/// Feature flag keys used across the app (API snapshot + PostHog `$feature/`).
///
/// Keep keys in sync with flags served by GET /config/features.
abstract final class FeatureFlags {
  static const onboardingInviteCode = 'onboarding-invite-code';
  static const marketingEmailNudgeOnFirstTip =
      'marketing-email-nudge-on-first-tip';
  static const closetBrowse = 'closet-browse';

  /// Keys attached as `$feature/<key>` on analytics capture.
  static const keys = [
    onboardingInviteCode,
    marketingEmailNudgeOnFirstTip,
    closetBrowse,
  ];
}
