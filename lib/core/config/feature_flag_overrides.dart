import 'package:gostylens/core/config/feature_flags.dart';

/// Local feature-flag values for debug and profile builds.
///
/// Add a key here to force a value without relying on PostHog — useful when
/// analytics are disabled in debug or when profiling UI locally.
///
/// Omit a key to fall through to PostHog (profile/release) or `false` in debug
/// when PostHog is not initialized.
///
/// Ignored in release builds unless injected via [FeatureFlagService] tests.
abstract final class FeatureFlagOverrides {
  static const Map<String, bool> debugAndProfile = {
    // see feature_flags.dart
    FeatureFlags.onboardingInviteCode: true,
  };
}
