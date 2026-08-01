import 'package:gostylens/core/services/api_service/asset_api_service.dart';

class _CachedSignedUrl {
  final String url;
  final DateTime expiresAt;

  const _CachedSignedUrl({required this.url, required this.expiresAt});

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// Resolves and caches R2 download URLs by object key.
///
/// API responses should seed the cache via [remember]. On 403, call [refresh]
/// so a stale entry is never reused.
class SignedUrlService {
  SignedUrlService(this._assetApiService);

  final AssetApiService _assetApiService;

  /// Conservative TTL under the API's 1-hour presign window.
  static const Duration defaultTtl = Duration(minutes: 50);

  final Map<String, _CachedSignedUrl> _cache = {};
  final Map<String, Future<String>> _inflight = {};

  /// Store a URL returned by the API (already freshly signed).
  void remember(String key, String url, {Duration ttl = defaultTtl}) {
    if (key.isEmpty || url.isEmpty) return;
    _cache[key] = _CachedSignedUrl(
      url: url,
      expiresAt: DateTime.now().add(ttl),
    );
  }

  /// Return a usable URL for [key], fetching from the API when needed.
  Future<String> resolve(String key, {String? hintUrl}) async {
    if (key.isEmpty) {
      return hintUrl ?? '';
    }

    final cached = _cache[key];
    if (cached != null && !cached.isExpired) {
      return cached.url;
    }

    if (hintUrl != null && hintUrl.isNotEmpty && cached == null) {
      // First sight of this key: trust the API-provided URL briefly.
      remember(key, hintUrl);
      return hintUrl;
    }

    return _fetchAndCache(key);
  }

  /// Drop any cached URL and fetch a new one (use after HTTP 403).
  Future<String> refresh(String key) async {
    if (key.isEmpty) return '';
    _cache.remove(key);
    _inflight.remove(key);
    return _fetchAndCache(key);
  }

  void invalidate(String key) {
    _cache.remove(key);
    _inflight.remove(key);
  }

  void clear() {
    _cache.clear();
    _inflight.clear();
  }

  Future<String> _fetchAndCache(String key) {
    final existing = _inflight[key];
    if (existing != null) return existing;

    final future = _doFetch(key);
    _inflight[key] = future;
    return future.whenComplete(() {
      _inflight.remove(key);
    });
  }

  Future<String> _doFetch(String key) async {
    final url = await _assetApiService.getDownloadUrl(key);
    if (url.isEmpty) {
      throw StateError('Empty download URL for key: $key');
    }
    remember(key, url);
    return url;
  }
}
