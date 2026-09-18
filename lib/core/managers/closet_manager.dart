import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:gostylens/core/config/dependency_injection.dart';
import 'package:gostylens/core/services/api_service/closet_api_service.dart';
import 'package:gostylens/core/services/realtime_service.dart';
import 'package:gostylens/models/closet_identity_status.dart';
import 'package:gostylens/models/closet_item.dart';
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

  final ClosetApiService _apiService;
  final RealtimeService? _realtimeService;
  final ClosetBroadcastListen? _onBroadcast;
  final void Function(String channel)? _leaveChannel;
  final Stream<RealtimeSubscribeStatus> Function(String channel)?
  _onChannelStatus;

  List<ClosetItem> _items = const [];
  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _error;
  String? _dbId;
  ClosetIdentityStatus _status = const ClosetIdentityStatus();
  bool _waitChrome = false;
  bool _failedEmpty = false;
  bool _observingLifecycle = false;
  StreamSubscription<Map<String, dynamic>>? _identitySub;
  StreamSubscription<Map<String, dynamic>>? _catalogSub;
  StreamSubscription<RealtimeSubscribeStatus>? _channelStatusSub;
  Future<void>? _itemsInFlight;

  List<ClosetItem> get items => _items;
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  String? get error => _error;
  ClosetIdentityStatus get identityStatus => _status;

  /// Wait chrome: empty hang state, dock chip, hanger badge, session pill.
  bool get isProcessing => _waitChrome;

  /// Wait chrome was up, the wave settled, and the catalog is still empty.
  bool get isFailedEmpty => _failedEmpty;

  String _channelFor(String dbId) => 'closet-identity:$dbId';

  Future<void> bindUser(String dbId) async {
    if (_dbId == dbId) {
      await syncIdentity(hideIfIdle: false);
      return;
    }

    reset(notify: false);
    _dbId = dbId;
    _subscribe(dbId);
    _ensureLifecycleObserver();
    await syncIdentity(hideIfIdle: true);
  }

  /// Catch-up GET for status + items. [hideIfIdle] is true on bind/resume/
  /// subscribe-rejoin so a missed `settled` can clear chrome. False while
  /// already showing chrome in-session (quiet window).
  Future<void> syncIdentity({bool hideIfIdle = false}) async {
    if (_dbId == null) return;
    await Future.wait([
      _fetchStatus(hideIfIdle: hideIfIdle),
      fetchItems(forceRefresh: true),
    ]);
  }

  Future<void> onAppResumed() => syncIdentity(hideIfIdle: true);

  Future<void> fetchItems({bool forceRefresh = false}) {
    final future = _fetchItems(forceRefresh: forceRefresh);
    _itemsInFlight = future;
    return future;
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
    try {
      final response = await _apiService.getIdentityStatus();
      if (_dbId == null) return;
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

  void _subscribe(String dbId) {
    _identitySub = _listen(dbId, identityUpdatedEvent).listen(_onIdentityEvent);
    _catalogSub = _listen(dbId, catalogUpdatedEvent).listen(_onCatalogEvent);
    _channelStatusSub = _statusListen(dbId).listen((status) {
      if (status == RealtimeSubscribeStatus.subscribed && _dbId == dbId) {
        syncIdentity(hideIfIdle: true);
      }
    });
  }

  Stream<Map<String, dynamic>> _listen(String dbId, String event) {
    final channel = _channelFor(dbId);
    if (_onBroadcast != null) {
      return _onBroadcast(channel: channel, event: event);
    }
    final realtime = _realtimeService ?? locator<RealtimeService>();
    return realtime.onBroadcast(channel: channel, event: event);
  }

  Stream<RealtimeSubscribeStatus> _statusListen(String dbId) {
    final channel = _channelFor(dbId);
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
    if (_dbId == null) return;
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
    if (_dbId == null) return;
    final ids = payload['closet_item_ids'];
    if (ids is List && ids.isEmpty) return;
    fetchItems(forceRefresh: true);
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
    await fetchItems(forceRefresh: true);
    if (wasWaiting && _items.isEmpty) {
      _failedEmpty = true;
      notifyListeners();
    }
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
    final dbId = _dbId;
    if (dbId == null) return;
    final channel = _channelFor(dbId);
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
    _dbId = null;
    _status = const ClosetIdentityStatus();
    _waitChrome = false;
    _failedEmpty = false;
    _items = const [];
    _isLoading = false;
    _hasLoaded = false;
    _error = null;
    if (notify) notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _dbId != null) {
      onAppResumed();
    }
  }

  @override
  void dispose() {
    reset(notify: false);
    super.dispose();
  }
}
