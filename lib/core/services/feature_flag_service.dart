import 'package:flutter/foundation.dart';
import 'package:gostylens/core/config/dependency_injection.dart';
import 'package:gostylens/core/config/feature_flag_overrides.dart';
import 'package:gostylens/core/config/feature_flags.dart';
import 'package:gostylens/core/services/api_service/config_api_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Resolves feature flags from local overrides (debug/profile) or the API
/// snapshot from [ConfigApiService.getFeatures].
class FeatureFlagService {
  FeatureFlagService({
    Map<String, bool>? overrides,
    Future<Map<String, Object>?> Function()? fetchFeatures,
  }) : _overrides = overrides,
       _fetchFeatures = fetchFeatures;

  /// Optional override map — used in tests. When null, uses
  /// [FeatureFlagOverrides.debugAndProfile] in debug/profile builds.
  final Map<String, bool>? _overrides;

  /// Optional snapshot fetch — used in tests. Defaults to GET /config/features.
  /// Return a map on success (including empty). Return null on failure so a
  /// previously cached map is kept.
  final Future<Map<String, Object>?> Function()? _fetchFeatures;

  Map<String, Object>? _flags;
  Future<void>? _loadPending;

  /// True after a failed load with no cache, so [isEnabled] does not hammer
  /// the network until an explicit [refresh] or [clear].
  bool _suppressAutoFetch = false;

  /// Last successfully loaded snapshot, or null before the first success.
  Map<String, Object>? get snapshot => _flags;

  bool get hasSnapshot => _flags != null;

  Future<bool> isEnabled(String key) async {
    final local = _resolveLocalOverride(key);
    if (local != null) return local;
    await _ensureLoaded();
    return _flags?[key] == true;
  }

  /// String variant for [key], or null when missing / boolean / not loaded.
  Future<String?> variant(String key) async {
    await _ensureLoaded();
    final value = _flags?[key];
    return value is String ? value : null;
  }

  /// Cached [FeatureFlags.closetBrowse] for this signed-in session.
  Future<bool> closetBrowseEnabled() => isEnabled(FeatureFlags.closetBrowse);

  /// Drops the flag snapshot. Call on logout so the next user is re-read.
  void clear() {
    _flags = null;
    _loadPending = null;
    _suppressAutoFetch = false;
  }

  /// Fetches a fresh snapshot. On failure, keeps any existing cache.
  Future<void> refresh() async {
    _suppressAutoFetch = false;
    final pending = _loadPending;
    if (pending != null) {
      await pending;
      return;
    }
    final future = _loadSnapshot();
    _loadPending = future;
    await future;
  }

  Future<void> _ensureLoaded() async {
    if (_flags != null) return;
    final pending = _loadPending;
    if (pending != null) {
      await pending;
      return;
    }
    if (_suppressAutoFetch) return;
    await refresh();
  }

  Future<void> _loadSnapshot() async {
    try {
      final fetch = _fetchFeatures ?? _fetchFromApi;
      final result = await fetch();
      if (result != null) {
        _flags = Map<String, Object>.unmodifiable(result);
        _suppressAutoFetch = false;
      } else if (_flags == null) {
        _suppressAutoFetch = true;
      }
      debugPrint('FeatureFlagService: loaded features: $_flags');
    } catch (e, st) {
      debugPrint('FeatureFlagService: failed to load features: $e\n$st');
      if (_flags == null) {
        _suppressAutoFetch = true;
      }
    } finally {
      _loadPending = null;
    }
  }

  Future<Map<String, Object>?> _fetchFromApi() async {
    if (!locator.isRegistered<SupabaseClient>()) return null;
    final user = locator<SupabaseClient>().auth.currentUser;
    if (user == null) return null;

    if (!locator.isRegistered<ConfigApiService>()) return null;
    final response = await locator<ConfigApiService>().getFeatures();
    if (!response.isSuccess) return null;
    return response.data ?? const {};
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
