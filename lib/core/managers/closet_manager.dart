import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:gostylens/core/config/dependency_injection.dart';
import 'package:gostylens/core/services/api_service/closet_api_service.dart';
import 'package:gostylens/core/services/realtime_service.dart';
import 'package:gostylens/models/closet_identity_status.dart';
import 'package:gostylens/models/closet_item.dart';
import 'package:gostylens/models/closet_pending_match.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef ClosetBroadcastListen =
    Stream<Map<String, dynamic>> Function({
      required String channel,
      required String event,
    });

/// Server closet list plus identity-wave wait chrome.
///
/// Search and All/Categories stay in the browse view.
class ClosetManager extends ChangeNotifier with WidgetsBindingObserver {
  ClosetManager({
    ClosetApiService? apiService,
    RealtimeService? realtimeService,
    ClosetBroadcastListen? onBroadcast,
    void Function(String channel)? leaveChannel,
    Stream<RealtimeSubscribeStatus> Function(String channel)? onChannelStatus,
  }) : _apiService = apiService ?? locator<ClosetApiService>(),
       _realtimeService = realtimeService,
       _onBroadcast = onBroadcast,
       _leaveChannel = leaveChannel,
       _onChannelStatus = onChannelStatus;

  static const identityUpdatedEvent = 'closet_identity_updated';
  static const catalogUpdatedEvent = 'closet_catalog_updated';
  static const settleDwell = Duration(milliseconds: 1600);

  final ClosetApiService _apiService;
  final RealtimeService? _realtimeService;
  final ClosetBroadcastListen? _onBroadcast;
  final void Function(String channel)? _leaveChannel;
  final Stream<RealtimeSubscribeStatus> Function(String channel)?
  _onChannelStatus;

  // Bind / session
  String? _userDbId;

  // Catalog (GET /closet/items)
  List<ClosetItem> _items = const [];
  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _error;
  Future<void>? _itemsInFlight;

  // Detail (GET /closet/items/:id) — fresh signed original + box
  final Map<String, ClosetItem> _details = {};
  final Set<String> _detailsLoading = {};
  final Map<String, String> _detailsErrors = {};
  final Map<String, int> _detailsStatusCodes = {};
  final Map<String, Future<ClosetItem?>> _detailsInFlight = {};

  // Identity wait chrome (GET status + closet_identity_updated)
  ClosetIdentityStatus _status = const ClosetIdentityStatus();
  bool _waitChrome = false;
  bool _failedEmpty = false;
  bool _debugPinned = false;

  // Realtime + resume
  bool _observingLifecycle = false;
  StreamSubscription<Map<String, dynamic>>? _identitySub;
  StreamSubscription<Map<String, dynamic>>? _catalogSub;
  StreamSubscription<RealtimeSubscribeStatus>? _channelStatusSub;

  // Pending asks (GET pending + POST resolve)
  List<ClosetPendingMatch> _pending = const [];
  ClosetAskSettle? _settle;
  Timer? _settleTimer;
  int _pendingEpoch = 0;
  bool _resolvingMatch = false;
  String? _matchResolveError;

  List<ClosetItem> get items => _items;
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  String? get error => _error;

  ClosetItem? itemById(String id) {
    final details = _details[id];
    if (details != null) return details;
    for (final item in _items) {
      if (item.id == id) return item;
    }
    return null;
  }

  ClosetItem? itemDetails(String id) => _details[id];

  bool isItemDetailsLoading(String id) => _detailsLoading.contains(id);

  String? itemDetailsError(String id) => _detailsErrors[id];

  int? itemDetailsStatusCode(String id) => _detailsStatusCodes[id];

  ClosetIdentityStatus get identityStatus => _status;

  /// Wait chrome: empty hang state, dock chip, hanger badge, session pill.
  bool get isProcessing => _waitChrome;

  /// Wait chrome was up, the wave settled, and the catalog is still empty.
  bool get isFailedEmpty => _failedEmpty;

  /// Newest-first queue from GET pending. Banner is [currentAsk].
  List<ClosetPendingMatch> get pendingMatches => _pending;

  /// Null while [askSettle] is showing so the banner does not skip ahead.
  ClosetPendingMatch? get currentAsk =>
      _settle != null || _pending.isEmpty ? null : _pending.first;

  ClosetAskSettle? get askSettle => _settle;

  bool get isResolvingMatch => _resolvingMatch;

  /// Set on 409 / failed resolve. Sheet stays open.
  String? get matchResolveError => _matchResolveError;

  String _channelFor(String userDbId) => 'closet-identity:$userDbId';

  Future<void> bindUser(String userDbId) async {
    if (_userDbId == userDbId) {
      await syncIdentity(hideIfIdle: false);
      return;
    }

    reset(notify: false);
    _userDbId = userDbId;
    _subscribe(userDbId);
    _ensureLifecycleObserver();
    await syncIdentity(hideIfIdle: true);
  }

  /// Catch-up GET for status, items, and pending asks. [hideIfIdle] is true
  /// on bind/resume/subscribe-rejoin so a missed `settled` can clear chrome.
  /// False while already showing chrome in-session (quiet window).
  Future<void> syncIdentity({bool hideIfIdle = false}) async {
    if (_userDbId == null) return;
    await Future.wait([
      _fetchStatus(hideIfIdle: hideIfIdle),
      fetchItems(forceRefresh: true),
      fetchPendingMatches(),
    ]);
  }

  Future<void> onAppResumed() => syncIdentity(hideIfIdle: true);

  /// Debug preview: cycle idle → processing → failed empty (empty catalog)
  /// or idle ↔ processing (filled). Resume/GET will not clear it until the
  /// cycle returns to idle. No-op in release.
  void debugCycleWaitChrome() {
    if (!kDebugMode) return;

    if (_items.isEmpty) {
      if (!_waitChrome && !_failedEmpty) {
        _debugPinned = true;
        _setWaitChrome(true);
      } else if (_waitChrome) {
        _debugPinned = true;
        _setWaitChrome(false);
        _failedEmpty = true;
      } else {
        _failedEmpty = false;
        _debugPinned = false;
      }
    } else if (!_waitChrome) {
      _debugPinned = true;
      _failedEmpty = false;
      _setWaitChrome(true);
    } else {
      _setWaitChrome(false);
      _debugPinned = false;
    }
    notifyListeners();
  }

  Future<void> fetchItems({bool forceRefresh = false}) {
    final future = _fetchItems(forceRefresh: forceRefresh);
    _itemsInFlight = future;
    return future;
  }

  /// Fresh signed original + box. Catalog row is still the immediate hero.
  /// Isolate URL from this payload must not replace the tile crop.
  Future<ClosetItem?> fetchItemDetails(String id) {
    final trimmed = id.trim();
    if (trimmed.isEmpty) return Future<ClosetItem?>.value(null);
    return _detailsInFlight.putIfAbsent(trimmed, () {
      return _fetchItemDetails(trimmed).whenComplete(() {
        _detailsInFlight.remove(trimmed);
      });
    });
  }

  Future<ClosetItem?> _fetchItemDetails(String id) async {
    _detailsLoading.add(id);
    _detailsErrors.remove(id);
    _detailsStatusCodes.remove(id);
    notifyListeners();

    try {
      final response = await _apiService.getItem(id);
      if (!response.isSuccess) {
        _detailsErrors[id] = response.errorMessage;
        _detailsStatusCodes[id] = response.statusCode;
        return null;
      }
      final item = response.data;
      if (item == null || item.id.isEmpty) {
        _detailsErrors[id] = 'Failed to load item';
        return null;
      }
      _details[id] = item;
      return item;
    } catch (e, st) {
      debugPrint('ClosetManager.fetchItemDetails failed: $e\n$st');
      _detailsErrors[id] = 'Failed to load item';
      return null;
    } finally {
      _detailsLoading.remove(id);
      notifyListeners();
    }
  }

  /// Catch-up GET for pending asks. Bind / resume / closet tab / settled /
  /// catalog ping. Do not poll.
  Future<void> fetchPendingMatches() async {
    if (_userDbId == null) return;
    final epoch = ++_pendingEpoch;
    try {
      final response = await _apiService.getPendingMatches();
      if (epoch != _pendingEpoch || _userDbId == null) return;
      if (!response.isSuccess) return;
      _applyPending(response.data ?? const []);
    } catch (e, st) {
      debugPrint('ClosetManager.getPendingMatches failed: $e\n$st');
    }
  }

  /// POST same / new for [currentAsk]. True if the sheet can close.
  /// 409 keeps the queue and [matchResolveError]. Last remaining skips settle.
  Future<bool> resolveCurrentAsk(ClosetMatchDecision decision) async {
    if (_userDbId == null || _settle != null || _resolvingMatch) return false;
    final ask = currentAsk;
    if (ask == null) return false;

    _resolvingMatch = true;
    _matchResolveError = null;
    notifyListeners();

    try {
      final response = await _apiService.resolveMatch(
        matchId: ask.id,
        decision: decision,
      );
      if (_userDbId == null) return false;

      if (!response.isSuccess) {
        if (response.statusCode == 404) {
          await fetchPendingMatches();
          _dropPendingId(ask.id);
          notifyListeners();
          return true;
        }
        _matchResolveError = response.errorMessage;
        return false;
      }

      final result = response.data;
      if (result?.decision == ClosetMatchDecision.ask) {
        await fetchPendingMatches();
        return true;
      }

      if (decision == ClosetMatchDecision.asNew) {
        await fetchItems(forceRefresh: true);
      }
      await fetchPendingMatches();
      _dropPendingId(ask.id);

      if (_pending.isEmpty) {
        _clearSettle();
        return true;
      }

      _beginSettle(
        decision == ClosetMatchDecision.asNew
            ? ClosetAskSettleKind.added
            : ClosetAskSettleKind.savedSame,
      );
      return true;
    } catch (e, st) {
      debugPrint('ClosetManager.resolveCurrentAsk failed: $e\n$st');
      _matchResolveError = 'Failed to resolve closet match';
      return false;
    } finally {
      _resolvingMatch = false;
      notifyListeners();
    }
  }

  Future<void> _fetchItems({required bool forceRefresh}) async {
    if (_isLoading) return;
    if (_hasLoaded && !forceRefresh && _error == null) return;

    final showSpinner = !_waitChrome && (!_hasLoaded || _items.isEmpty);
    _isLoading = showSpinner;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.getItems(forceRefresh: forceRefresh);
      if (response.isSuccess) {
        _items = List<ClosetItem>.unmodifiable(response.data ?? const []);
        _hasLoaded = true;
        _error = null;
        if (_items.isNotEmpty) _failedEmpty = false;
      } else {
        _error = response.errorMessage;
        _hasLoaded = true;
      }
    } catch (e, st) {
      debugPrint('ClosetManager.fetchItems failed: $e\n$st');
      _error = 'Failed to load closet';
      _hasLoaded = true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _fetchStatus({required bool hideIfIdle}) async {
    if (_debugPinned) return;
    try {
      final response = await _apiService.getIdentityStatus();
      if (_userDbId == null) return;
      if (!response.isSuccess || response.data == null) return;

      final status = response.data!;
      _status = status;
      if (status.processing) {
        _setWaitChrome(true);
        notifyListeners();
        return;
      }
      if (hideIfIdle) {
        await _hideWaitChrome(catchUpItems: _waitChrome);
        return;
      }
      notifyListeners();
    } catch (e, st) {
      debugPrint('ClosetManager.getIdentityStatus failed: $e\n$st');
    }
  }

  void _subscribe(String userDbId) {
    _identitySub = _listen(
      userDbId,
      identityUpdatedEvent,
    ).listen(_onIdentityEvent);
    _catalogSub = _listen(
      userDbId,
      catalogUpdatedEvent,
    ).listen(_onCatalogEvent);
    _channelStatusSub = _statusListen(userDbId).listen((status) {
      if (status == RealtimeSubscribeStatus.subscribed &&
          _userDbId == userDbId) {
        syncIdentity(hideIfIdle: true);
      }
    });
  }

  Stream<Map<String, dynamic>> _listen(String userDbId, String event) {
    final channel = _channelFor(userDbId);
    if (_onBroadcast != null) {
      return _onBroadcast(channel: channel, event: event);
    }
    final realtime = _realtimeService ?? locator<RealtimeService>();
    return realtime.onBroadcast(channel: channel, event: event);
  }

  Stream<RealtimeSubscribeStatus> _statusListen(String userDbId) {
    final channel = _channelFor(userDbId);
    if (_onChannelStatus != null) {
      return _onChannelStatus(channel);
    }
    if (_onBroadcast != null) {
      return const Stream.empty();
    }
    final realtime = _realtimeService ?? locator<RealtimeService>();
    return realtime.onChannelStatus(channel);
  }

  void _onIdentityEvent(Map<String, dynamic> payload) {
    if (_userDbId == null || _debugPinned) return;
    final status = ClosetIdentityStatus.fromResponse(payload);
    _status = status;

    if (status.phase == ClosetIdentityPhase.started || status.processing) {
      _setWaitChrome(true);
      notifyListeners();
      return;
    }
    if (status.phase == ClosetIdentityPhase.settled) {
      _hideWaitChrome(catchUpItems: true);
      return;
    }
    notifyListeners();
  }

  void _onCatalogEvent(Map<String, dynamic> payload) {
    if (_userDbId == null) return;
    final ids = payload['closet_item_ids'];
    if (ids is! List || ids.isNotEmpty) {
      fetchItems(forceRefresh: true);
    }
    unawaited(fetchPendingMatches());
  }

  void _setWaitChrome(bool value) {
    if (value) _failedEmpty = false;
    if (_waitChrome == value) return;
    _waitChrome = value;
  }

  Future<void> _hideWaitChrome({required bool catchUpItems}) async {
    final wasWaiting = _waitChrome;
    _setWaitChrome(false);
    notifyListeners();
    if (!catchUpItems) return;

    if (_isLoading) await _itemsInFlight;
    await Future.wait([fetchItems(forceRefresh: true), fetchPendingMatches()]);
    if (wasWaiting && _items.isEmpty) {
      _failedEmpty = true;
      notifyListeners();
    }
  }

  void _applyPending(List<ClosetPendingMatch> matches) {
    _pending = List<ClosetPendingMatch>.unmodifiable(matches);
    if (_pending.isEmpty) _clearSettle();
    if (!_resolvingMatch) notifyListeners();
  }

  void _dropPendingId(String id) {
    if (_pending.every((match) => match.id != id)) return;
    _pending = List<ClosetPendingMatch>.unmodifiable(
      _pending.where((match) => match.id != id),
    );
    if (_pending.isEmpty) _clearSettle();
  }

  void _beginSettle(ClosetAskSettleKind kind) {
    _settleTimer?.cancel();
    _settle = ClosetAskSettle(kind: kind, remaining: _pending.length);
    _settleTimer = Timer(settleDwell, () {
      _settleTimer = null;
      _settle = null;
      notifyListeners();
    });
  }

  void _clearSettle() {
    _settleTimer?.cancel();
    _settleTimer = null;
    _settle = null;
  }

  void _ensureLifecycleObserver() {
    if (_observingLifecycle) return;
    WidgetsBinding.instance.addObserver(this);
    _observingLifecycle = true;
  }

  void _removeLifecycleObserver() {
    if (!_observingLifecycle) return;
    WidgetsBinding.instance.removeObserver(this);
    _observingLifecycle = false;
  }

  void _leaveIdentityChannel() {
    final userDbId = _userDbId;
    if (userDbId == null) return;
    final channel = _channelFor(userDbId);
    if (_leaveChannel != null) {
      _leaveChannel(channel);
      return;
    }
    try {
      (_realtimeService ?? locator<RealtimeService>()).leaveChannel(channel);
    } catch (e, st) {
      debugPrint('ClosetManager.leaveChannel failed: $e\n$st');
    }
  }

  /// Drop identity chrome, catalog, and the realtime channel. Call on logout.
  void reset({bool notify = true}) {
    _identitySub?.cancel();
    _catalogSub?.cancel();
    _channelStatusSub?.cancel();
    _identitySub = null;
    _catalogSub = null;
    _channelStatusSub = null;
    _leaveIdentityChannel();
    _removeLifecycleObserver();

    _userDbId = null;

    _status = const ClosetIdentityStatus();
    _waitChrome = false;
    _failedEmpty = false;
    _debugPinned = false;

    _pendingEpoch += 1;
    _pending = const [];
    _clearSettle();
    _resolvingMatch = false;
    _matchResolveError = null;

    _items = const [];
    _isLoading = false;
    _hasLoaded = false;
    _error = null;
    _details.clear();
    _detailsLoading.clear();
    _detailsErrors.clear();
    _detailsStatusCodes.clear();
    _detailsInFlight.clear();
    if (notify) notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _userDbId != null) {
      onAppResumed();
    }
  }

  @override
  void dispose() {
    reset(notify: false);
    super.dispose();
  }
}
