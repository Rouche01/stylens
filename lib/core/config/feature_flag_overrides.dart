import 'package:gostylens/core/config/feature_flags.dart';

/// Local feature-flag values for debug and profile builds.
///
/// Add a key here to force a value without relying on the API snapshot —
/// useful when the config endpoint is unavailable or when profiling UI locally.
///
/// Omit a key to fall through to the API snapshot (or `false` before load /
/// when logged out).
///
/// Ignored in release builds unless injected via [FeatureFlagService] tests.
abstract final class FeatureFlagOverrides {
  static const Map<String, bool> debugAndProfile = {
    // see feature_flags.dart
    FeatureFlags.onboardingInviteCode: true,
    FeatureFlags.marketingEmailNudgeOnFirstTip: true,
    FeatureFlags.closetBrowse: true,
  };
}
