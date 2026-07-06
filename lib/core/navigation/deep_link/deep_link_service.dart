import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:gostylens/core/navigation/deep_link/deep_link_destination.dart';
import 'package:gostylens/core/navigation/deep_link/deep_link_parser.dart';
import 'package:gostylens/core/navigation/deep_link/deep_link_router.dart';
import 'package:gostylens/core/navigation/deep_link/pending_deep_link.dart';
import 'package:gostylens/navigation/app_routes.dart';

class DeepLinkService {
  DeepLinkService({
    AppLinks? appLinks,
    DeepLinkParser? parser,
    DeepLinkRouter? router,
  })  : _appLinks = appLinks ?? AppLinks(),
        _parser = parser ?? DeepLinkParser(),
        _router = router ?? DeepLinkRouter();

  final AppLinks _appLinks;
  final DeepLinkParser _parser;
  final DeepLinkRouter _router;

  StreamSubscription<Uri>? _linkSubscription;
  PendingDeepLink? _pending;
  bool _navigationReady = false;

  bool get hasPending => _pending != null;

  @visibleForTesting
  bool get navigationReady => _navigationReady;

  /// Subscribes to warm-resume custom-scheme links. Cold-start links are handled
  /// by GoRouter's platform route provider and [redirectForDeepLinkUri].
  Future<void> initialize() async {
    _linkSubscription ??= _appLinks.uriLinkStream.listen(
      _handleUri,
      onError: (Object error, StackTrace stackTrace) {
        if (kDebugMode) {
          print('DeepLinkService uriLinkStream error: $error');
        }
      },
    );
  }

  /// Tracks whether the app shell is ready for imperative deep-link navigation
  /// (push stream, push notifications). Pending destinations are consumed by
  /// GoRouter redirect via [takePendingDestination] when auth reaches userReady.
  void setNavigationReady(bool ready) {
    _navigationReady = ready;
  }

  /// Stashes a destination for later (auth gating or deferred push-detail).
  void stashPendingDestination(DeepLinkDestination destination) {
    _pending = PendingDeepLink(
      destination: destination,
      shellLocation: semanticShellFor(destination.target),
    );
  }

  /// Returns and clears the stashed pending link, if any.
  PendingDeepLink? takePendingDestination() {
    final pending = _pending;
    _pending = null;
    return pending;
  }

  /// Pushes a full-screen detail route after the current navigation frame.
  void schedulePushDetail(DeepLinkDestination destination) {
    _router.schedulePushDetail(destination);
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
      stashPendingDestination(destination);
      return;
    }
    _dispatch(destination);
  }

  void _dispatch(DeepLinkDestination destination) {
    // Warm-resume fallback when uriLinkStream fires without a matching platform
    // redirect. Tab `go` and guarded `push` are idempotent if both paths run.
    _router.navigate(destination);
  }
}
