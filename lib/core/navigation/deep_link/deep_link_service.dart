import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:gostylens/core/navigation/deep_link/deep_link_destination.dart';
import 'package:gostylens/core/navigation/deep_link/deep_link_parser.dart';
import 'package:gostylens/core/navigation/deep_link/deep_link_router.dart';

class DeepLinkService {
  DeepLinkService({
    AppLinks? appLinks,
    DeepLinkParser? parser,
    DeepLinkRouter? router,
    Duration duplicateWindow = const Duration(milliseconds: 1500),
  })  : _appLinks = appLinks ?? AppLinks(),
        _parser = parser ?? DeepLinkParser(),
        _router = router ?? DeepLinkRouter(),
        _duplicateWindow = duplicateWindow;

  final AppLinks _appLinks;
  final DeepLinkParser _parser;
  final DeepLinkRouter _router;

  /// iOS can deliver the same custom-scheme link several times for a single tap.
  /// Identical destinations within this window are ignored to avoid push/pop
  /// churn that would otherwise leave the user back on the previous screen.
  final Duration _duplicateWindow;

  StreamSubscription<Uri>? _linkSubscription;
  DeepLinkDestination? _pending;
  bool _navigationReady = false;

  DeepLinkTarget? _lastDispatchedTarget;
  String? _lastDispatchedSessionId;
  DateTime? _lastDispatchedAt;

  bool get hasPending => _pending != null;

  @visibleForTesting
  bool get navigationReady => _navigationReady;

  Future<void> initialize() async {
    final initialUri = await _appLinks.getInitialLink();
    if (initialUri != null) {
      _handleUri(initialUri);
    }

    _linkSubscription ??= _appLinks.uriLinkStream.listen(
      _handleUri,
      onError: (Object error, StackTrace stackTrace) {
        if (kDebugMode) {
          print('DeepLinkService uriLinkStream error: $error');
        }
      },
    );
  }

  void setNavigationReady(bool ready) {
    _navigationReady = ready;
    if (!ready) return;
    consumePending();
  }

  void consumePending() {
    if (!_navigationReady || _pending == null) return;

    final destination = _pending!;
    _pending = null;
    _dispatch(destination);
  }

  void handlePushData(Map<String, dynamic> data) {
    final destination = _parser.parsePushData(data);
    _enqueueOrDispatch(destination);
  }

  void dispose() {
    _linkSubscription?.cancel();
    _linkSubscription = null;
  }

  void _handleUri(Uri uri) {
    final destination = _parser.parseUri(uri);
    if (destination == null) return;

    _enqueueOrDispatch(destination);
  }

  void _enqueueOrDispatch(DeepLinkDestination destination) {
    if (!_navigationReady) {
      _pending = destination;
      return;
    }
    _dispatch(destination);
  }

  void _dispatch(DeepLinkDestination destination) {
    if (_isDuplicate(destination)) return;

    // The router resolves the root navigator and retries across frames if it is
    // not mounted yet, so no extra scheduling/defer is needed here. Stack
    // cleanup on auth transitions happens before pending links are consumed
    // (see AuthFlowController), so a pushed route is never popped after landing.
    _router.navigate(destination);
  }

  bool _isDuplicate(DeepLinkDestination destination) {
    final now = DateTime.now();
    final isSameDestination = _lastDispatchedTarget == destination.target &&
        _lastDispatchedSessionId == destination.sessionId;
    final withinWindow = _lastDispatchedAt != null &&
        now.difference(_lastDispatchedAt!) < _duplicateWindow;

    if (isSameDestination && withinWindow) return true;

    _lastDispatchedTarget = destination.target;
    _lastDispatchedSessionId = destination.sessionId;
    _lastDispatchedAt = now;
    return false;
  }
}
