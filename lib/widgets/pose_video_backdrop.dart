import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gostylens/navigation/app_routes.dart';
import 'package:video_player/video_player.dart';

/// Muted looping pose clip for the capture card.
///
/// Pauses when the Capture tab is off-screen, covered by a pushed route,
/// the app is backgrounded, or the user requested reduced motion.
class PoseVideoBackdrop extends StatefulWidget {
  const PoseVideoBackdrop({super.key});

  static const videoAsset = 'assets/videos/strike_a_pose.mp4';
  static const posterAsset = 'assets/imgs/capture/strike_a_pose_poster.jpg';

  @override
  State<PoseVideoBackdrop> createState() => _PoseVideoBackdropState();
}

class _PoseVideoBackdropState extends State<PoseVideoBackdrop>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  GoRouter? _router;
  Timer? _loopTimer;
  var _ready = false;
  var _tickersEnabled = true;
  var _reduceMotion = false;
  var _restarting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initController();
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
    _controller?.dispose();
    _controller = null;
    super.dispose();
  }

  Future<void> _initController() async {
    final controller = VideoPlayerController.asset(
      PoseVideoBackdrop.videoAsset,
      videoPlayerOptions: VideoPlayerOptions(
        mixWithOthers: true,
        preventsDisplaySleepDuringVideoPlayback: false,
      ),
    );
    try {
      await controller.initialize();
      await controller.setVolume(0);
      await controller.setLooping(true);
    } catch (e, stackTrace) {
      debugPrint('PoseVideoBackdrop failed to load: $e\n$stackTrace');
      await controller.dispose();
      return;
    }

    if (!mounted) {
      await controller.dispose();
      return;
    }

    setState(() {
      _controller = controller;
      _ready = true;
    });
    _syncPlayback();
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
    if (!mounted || !_ready) return false;
    if (_reduceMotion || !_tickersEnabled) return false;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) {
      return false;
    }
    return _isCaptureForeground;
  }

  Future<void> _ensurePlaying() async {
    if (_restarting) return;
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    if (!_shouldPlay) {
      _stopLoopWatchdog();
      if (controller.value.isPlaying) await controller.pause();
      return;
    }

    _startLoopWatchdog();
    if (controller.value.isPlaying) return;

    _restarting = true;
    try {
      if (controller.value.position > Duration.zero) {
        await controller.seekTo(Duration.zero);
      }
      if (mounted && _shouldPlay) {
        await controller.play();
      }
    } finally {
      _restarting = false;
    }
  }

  void _syncPlayback() {
    unawaited(_ensurePlaying());
  }

  /// iOS `setLooping` can seek to 0 without `play()`. Only poll while Capture
  /// is actually in the foreground.
  void _startLoopWatchdog() {
    if (_loopTimer != null) return;
    _loopTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      _ensurePlaying();
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

    final controller = _controller;
    final showVideo = _ready && controller != null && !_reduceMotion;
    final size = controller?.value.size;

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: Image.asset(
            PoseVideoBackdrop.posterAsset,
            fit: BoxFit.cover,
            alignment: const Alignment(0, -0.2),
          ),
        ),
        if (showVideo && size != null && size.width > 0 && size.height > 0)
          Positioned.fill(
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
      ],
    );
  }
}
