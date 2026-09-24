import 'package:flutter/foundation.dart';
import 'package:gostylens/core/config/feature_flag_overrides.dart';
import 'package:gostylens/core/config/feature_flags.dart';
import 'package:gostylens/core/services/analytics_service.dart';

/// Resolves feature flags from local overrides (debug/profile) or PostHog.
class FeatureFlagService {
  FeatureFlagService(
    this._analytics, {
    Map<String, bool>? overrides,
    Future<bool> Function(String key)? fetchRemote,
  }) : _overrides = overrides,
       _fetchRemote = fetchRemote;

  final AnalyticsService _analytics;

  /// Optional override map — used in tests. When null, uses
  /// [FeatureFlagOverrides.debugAndProfile] in debug/profile builds.
  final Map<String, bool>? _overrides;

  /// Optional remote lookup — used in tests. Defaults to PostHog.
  final Future<bool> Function(String key)? _fetchRemote;

  bool? _closetBrowse;
  Future<bool>? _closetBrowsePending;

  Future<bool> isEnabled(String key) async {
    final local = _resolveLocalOverride(key);
    if (local != null) return local;
    return _fetch(key);
  }

  /// Cached [FeatureFlags.closetBrowse] for this signed-in session.
  Future<bool> closetBrowseEnabled() {
    final cached = _closetBrowse;
    if (cached != null) return Future<bool>.value(cached);
    return _closetBrowsePending ??= _loadClosetBrowse();
  }

  /// Drops the closet browse cache. Call on logout so the next user is re-read.
  void clearClosetBrowse() {
    _closetBrowse = null;
    _closetBrowsePending = null;
  }

  Future<bool> _loadClosetBrowse() async {
    final enabled = await isEnabled(FeatureFlags.closetBrowse);
    _closetBrowse = enabled;
    _closetBrowsePending = null;
    return enabled;
  }

  Future<bool> _fetch(String key) {
    final fetchRemote = _fetchRemote;
    if (fetchRemote != null) return fetchRemote(key);
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
