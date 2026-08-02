import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:gostylens/constants/ux_messages.dart';
import 'package:gostylens/core/config/dependency_injection.dart';
import 'package:gostylens/core/services/api_service/config_api_service.dart';
import 'package:gostylens/models/api_responses/stylist_openers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StylistOpenersManager with WidgetsBindingObserver {
  StylistOpenersManager({
    ConfigApiService? apiService,
    Random? random,
    Duration refreshInterval = const Duration(hours: 1),
    int recentIdsLimit = 15,
  }) : _apiServiceOverride = apiService,
       _random = random ?? Random(),
       _refreshInterval = refreshInterval,
       _recentIdsLimit = recentIdsLimit {
    WidgetsBinding.instance.addObserver(this);
  }

  static const _poolKey = 'stylist_openers_pool';
  static const _checkedAtKey = 'stylist_openers_checked_at';
  static const _recentIdsKey = 'stylist_openers_recent_ids';

  final ConfigApiService? _apiServiceOverride;
  final Random _random;
  final Duration _refreshInterval;
  final int _recentIdsLimit;

  ConfigApiService get _apiService =>
      _apiServiceOverride ?? locator<ConfigApiService>();

  StylistOpenersPool? _pool;
  List<String> _recentIds = [];
  DateTime? _lastCheckedAt;
  bool _loaded = false;
  bool _refreshInFlight = false;

  StylistOpenersPool? get pool => _pool;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ensureFresh();
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }

  Future<void> ensureFresh({bool force = false}) async {
    await _ensureLoaded();
    if (_refreshInFlight) return;

    final now = DateTime.now();
    final checkedAt = _lastCheckedAt;
    final isStale =
        force ||
        checkedAt == null ||
        now.difference(checkedAt) >= _refreshInterval;

    if (!isStale) return;

    _refreshInFlight = true;
    try {
      final etag = _pool != null && _pool!.version > 0
          ? '"${_pool!.version}"'
          : null;
      final response = await _apiService.getStylistOpeners(ifNoneMatch: etag);

      if (!response.isSuccess) {
        debugPrint(
          'StylistOpenersManager: refresh failed (${response.statusCode})',
        );
        return;
      }

      if (response.statusCode == 304) {
        _lastCheckedAt = now;
        await _persistMeta();
        return;
      }

      final next = response.data;
      if (next == null || next.messages.isEmpty) {
        _lastCheckedAt = now;
        await _persistMeta();
        return;
      }

      _pool = next;
      _lastCheckedAt = now;
      await _persistAll();
    } catch (e) {
      debugPrint('StylistOpenersManager: refresh error: $e');
    } finally {
      _refreshInFlight = false;
    }
  }

  /// Picks [count] distinct messages for [tag], avoiding recently used IDs.
  /// Falls back to [UxMessages] when the cache has nothing usable.
  List<String> pickTexts({required StylistOpenerTag tag, int count = 1}) {
    assert(count >= 1);
    final selected = <StylistOpenerMessage>[];
    final candidates =
        _pool?.messages.where((m) => m.hasTag(tag)).toList(growable: false) ??
        const <StylistOpenerMessage>[];

    if (candidates.isNotEmpty) {
      final unused = candidates
          .where((m) => !_recentIds.contains(m.id))
          .toList(growable: false);
      final drawFrom = unused.isNotEmpty ? unused : candidates;
      final shuffled = List<StylistOpenerMessage>.from(drawFrom)
        ..shuffle(_random);

      for (final message in shuffled) {
        if (selected.any((m) => m.id == message.id)) continue;
        selected.add(message);
        if (selected.length >= count) break;
      }

      // If we still need more (tiny pool), allow reuse from full candidates.
      if (selected.length < count) {
        final rest = List<StylistOpenerMessage>.from(candidates)
          ..shuffle(_random);
        for (final message in rest) {
          if (selected.any((m) => m.id == message.id)) continue;
          selected.add(message);
          if (selected.length >= count) break;
        }
      }
    }

    if (selected.isEmpty) {
      return _fallbackTexts(tag: tag, count: count);
    }

    _rememberIds(selected.map((m) => m.id));
    // Fire-and-forget persist; sync pick path must stay sync for intros.
    unawaited(_persistRecentIds());

    if (selected.length >= count) {
      return selected.map((m) => m.text).toList(growable: false);
    }

    final texts = selected.map((m) => m.text).toList();
    texts.addAll(_fallbackTexts(tag: tag, count: count - selected.length));
    return texts;
  }

  String pickOne(StylistOpenerTag tag) => pickTexts(tag: tag, count: 1).first;

  List<String> _fallbackTexts({
    required StylistOpenerTag tag,
    required int count,
  }) {
    final fallbacks = switch (tag) {
      StylistOpenerTag.withImage => [UxMessages.initialStylistReplyWithImage],
      StylistOpenerTag.withoutImage => [
        UxMessages.initialStylistReplyWithoutImage1,
        UxMessages.initialStylistReplyWithoutImage2,
      ],
    };

    if (count <= fallbacks.length) {
      return fallbacks.sublist(0, count);
    }

    final out = <String>[...fallbacks];
    while (out.length < count) {
      out.add(fallbacks[out.length % fallbacks.length]);
    }
    return out;
  }

  void _rememberIds(Iterable<String> ids) {
    for (final id in ids) {
      _recentIds.remove(id);
      _recentIds.add(id);
    }
    if (_recentIds.length > _recentIdsLimit) {
      _recentIds = _recentIds.sublist(_recentIds.length - _recentIdsLimit);
    }
  }

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final rawPool = prefs.getString(_poolKey);
    if (rawPool != null && rawPool.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawPool);
        if (decoded is Map<String, dynamic>) {
          _pool = StylistOpenersPool.fromJson(decoded);
        } else if (decoded is Map) {
          _pool = StylistOpenersPool.fromJson(
            Map<String, dynamic>.from(decoded),
          );
        }
      } catch (e) {
        debugPrint('StylistOpenersManager: failed to parse cached pool: $e');
      }
    }

    final checkedMs = prefs.getInt(_checkedAtKey);
    if (checkedMs != null) {
      _lastCheckedAt = DateTime.fromMillisecondsSinceEpoch(checkedMs);
    }

    final recent = prefs.getStringList(_recentIdsKey);
    if (recent != null) {
      _recentIds = List<String>.from(recent);
    }

    _loaded = true;
  }

  /// Loads prefs cache without hitting the network. Safe to call before pick.
  Future<void> warmCache() => _ensureLoaded();

  Future<void> _persistAll() async {
    final prefs = await SharedPreferences.getInstance();
    if (_pool != null) {
      await prefs.setString(_poolKey, jsonEncode(_pool!.toJson()));
    }
    await _persistMeta(prefs: prefs);
    await _persistRecentIds(prefs: prefs);
  }

  Future<void> _persistMeta({SharedPreferences? prefs}) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    if (_lastCheckedAt != null) {
      await store.setInt(_checkedAtKey, _lastCheckedAt!.millisecondsSinceEpoch);
    }
  }

  Future<void> _persistRecentIds({SharedPreferences? prefs}) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    await store.setStringList(_recentIdsKey, _recentIds);
  }

  /// Test helper: seed in-memory pool without prefs/network.
  @visibleForTesting
  void debugSetPool(StylistOpenersPool? pool, {List<String>? recentIds}) {
    _pool = pool;
    if (recentIds != null) {
      _recentIds = List<String>.from(recentIds);
    }
    _loaded = true;
  }
}
