import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gostylens/core/config/dependency_injection.dart';
import 'package:gostylens/core/services/pose_video_service.dart';
import 'package:gostylens/navigation/app_routes.dart';
import 'package:video_player/video_player.dart';

/// Muted looping pose clip for the capture card.
///
/// Pauses when the Capture tab is off-screen, covered by a pushed route,
/// the app is backgrounded, or the user requested reduced motion.
class PoseVideoBackdrop extends StatefulWidget {
  const PoseVideoBackdrop({super.key});

  static const videoAsset = PoseVideoService.videoAsset;
  static const posterAsset = PoseVideoService.posterAsset;

  @override
  State<PoseVideoBackdrop> createState() => _PoseVideoBackdropState();
}

class _PoseVideoBackdropState extends State<PoseVideoBackdrop>
    with WidgetsBindingObserver {
  final PoseVideoService _videoService = locator<PoseVideoService>();

  GoRouter? _router;
  Timer? _loopTimer;
  var _tickersEnabled = true;
  var _reduceMotion = false;
  var _hasShownVideo = false;

  static const _crossfadeDuration = Duration(milliseconds: 280);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(
      _videoService.ensureInitialized().then((_) {
        if (mounted) _syncPlayback();
      }),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final media = MediaQuery.of(context);
    _reduceMotion = media.disableAnimations || media.accessibleNavigation;
    _tickersEnabled = TickerMode.valuesOf(context).enabled;

    final router = GoRouter.of(context);
    if (!identical(_router, router)) {
      _router?.routerDelegate.removeListener(_syncPlayback);
      _router = router;
      _router!.routerDelegate.addListener(_syncPlayback);
    }
    _syncPlayback();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _syncPlayback();
  }

  @override
  void dispose() {
    _loopTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _router?.routerDelegate.removeListener(_syncPlayback);
    unawaited(_videoService.setPlayback(shouldPlay: false));
    super.dispose();
  }

  /// Visible Capture tab with nothing pushed over the shell.
  bool get _isCaptureForeground {
    final router = _router;
    if (router == null) return false;
    final config = router.routerDelegate.currentConfiguration;
    if (config.isEmpty) return false;
    return config.uri.path == AppRoutes.capture;
  }

  bool get _shouldPlay {
    if (!mounted || !_videoService.isReady) return false;
    if (_reduceMotion || !_tickersEnabled) return false;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) {
      return false;
    }
    return _isCaptureForeground;
  }

  Future<void> _applyPlayback() async {
    await _videoService.setPlayback(shouldPlay: _shouldPlay);

    final controller = _videoService.controller;
    if (_shouldPlay &&
        controller != null &&
        controller.value.isInitialized &&
        controller.value.isPlaying) {
      _hasShownVideo = true;
    }

    if (_shouldPlay) {
      _startLoopWatchdog();
    } else {
      _stopLoopWatchdog();
    }

    if (mounted) setState(() {});
  }

  void _syncPlayback() {
    if (_shouldPlay) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_applyPlayback());
      });
      return;
    }
    unawaited(_applyPlayback());
  }

  /// iOS `setLooping` can stall without `play()`. Android relies on native loop.
  void _startLoopWatchdog() {
    if (!Platform.isIOS || _loopTimer != null) return;
    _loopTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (_shouldPlay) {
        unawaited(_videoService.setPlayback(shouldPlay: true));
      }
    });
  }

  void _stopLoopWatchdog() {
    _loopTimer?.cancel();
    _loopTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    final tickersEnabled = TickerMode.valuesOf(context).enabled;
    if (tickersEnabled != _tickersEnabled) {
      _tickersEnabled = tickersEnabled;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncPlayback();
      });
    }

    final controller = _videoService.controller;
    final showVideoLayer =
        _videoService.isReady && controller != null && !_reduceMotion;
    final size = controller?.value.size;
    final videoOpacity = showVideoLayer && _hasShownVideo ? 1.0 : 0.0;

    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: Image.asset(
              PoseVideoService.posterAsset,
              fit: BoxFit.cover,
              alignment: const Alignment(0, -0.2),
            ),
          ),
          if (showVideoLayer && size != null && size.width > 0 && size.height > 0)
            Positioned.fill(
              child: AnimatedOpacity(
                duration: _crossfadeDuration,
                curve: Curves.easeOut,
                opacity: videoOpacity,
                child: FittedBox(
                  fit: BoxFit.cover,
                  alignment: const Alignment(0, -0.2),
                  clipBehavior: Clip.hardEdge,
                  child: SizedBox(
                    width: size.width,
                    height: size.height,
                    child: IgnorePointer(child: VideoPlayer(controller)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
