import 'package:flutter/foundation.dart';
import 'package:gostylens/core/config/feature_flag_overrides.dart';
import 'package:gostylens/core/services/analytics_service.dart';

/// Resolves feature flags from local overrides (debug/profile) or PostHog.
class FeatureFlagService {
  FeatureFlagService(
    this._analytics, {
    Map<String, bool>? overrides,
  }) : _overrides = overrides;

  final AnalyticsService _analytics;

  /// Optional override map — used in tests. When null, uses
  /// [FeatureFlagOverrides.debugAndProfile] in debug/profile builds.
  final Map<String, bool>? _overrides;

  Future<bool> isEnabled(String key) async {
    final local = _resolveLocalOverride(key);
    if (local != null) return local;
    return _analytics.fetchRemoteFeatureFlag(key);
  }

  bool? _resolveLocalOverride(String key) {
    final Map<String, bool>? source;
    if (_overrides != null) {
      source = _overrides;
    } else if (kDebugMode || kProfileMode) {
      source = FeatureFlagOverrides.debugAndProfile;
    } else {
      return null;
    }

    if (!source.containsKey(key)) return null;
    return source[key];
  }
}
