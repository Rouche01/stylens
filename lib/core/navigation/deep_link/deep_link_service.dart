import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:gostylens/core/navigation/deep_link/deep_link_destination.dart';
import 'package:gostylens/core/navigation/deep_link/deep_link_parser.dart';
import 'package:gostylens/core/navigation/deep_link/deep_link_router.dart';

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
  DeepLinkDestination? _pending;
  bool _navigationReady = false;

  bool get hasPending => _pending != null;

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
    if (kDebugMode) {
      print('DeepLinkService received uri: $uri');
    }

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
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _router.navigate(destination);
    });
  }
}
