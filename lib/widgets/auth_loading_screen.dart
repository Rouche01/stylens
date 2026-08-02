import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:lottie/lottie.dart';

/// Display size of the logo-reveal Lottie (composition is 1080×1080).
const double _splashLottieSize = 300;

/// On-screen width of the GoStylens wordmark inside [_splashLottieSize].
///
/// Wordmark path bounds span ~873 of 1080 composition units. Native splash
/// `logo_splash.png` is sized so its @1x asset matches this width.
const double _splashLogoWidth = _splashLottieSize * 873 / 1080;

/// Branded full-screen loader shown while auth bootstrap completes.
///
/// Plays the preloaded logo-reveal once, holds the last frame, and reports
/// completion via [onRevealCompleted]. Removes the native splash only after
/// the first Lottie frame is ready to paint.
class AuthLoadingScreen extends StatefulWidget {
  const AuthLoadingScreen({
    required this.onRevealCompleted,
    this.composition,
    super.key,
  });

  final LottieComposition? composition;
  final VoidCallback onRevealCompleted;

  @override
  State<AuthLoadingScreen> createState() => _AuthLoadingScreenState();
}

class _AuthLoadingScreenState extends State<AuthLoadingScreen>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  bool _nativeSplashRemoved = false;
  bool _revealReported = false;

  @override
  void initState() {
    super.initState();
    final composition = widget.composition;
    if (composition != null) {
      _controller = AnimationController(
        vsync: this,
        duration: composition.duration,
      )..addStatusListener(_onAnimationStatus);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _removeNativeSplash();
        _controller?.forward();
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _removeNativeSplash();
        _reportRevealCompleted();
      });
    }
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _reportRevealCompleted();
    }
  }

  void _removeNativeSplash() {
    if (_nativeSplashRemoved) return;
    _nativeSplashRemoved = true;
    FlutterNativeSplash.remove();
  }

  void _reportRevealCompleted() {
    if (_revealReported) return;
    _revealReported = true;
    widget.onRevealCompleted();
  }

  @override
  void dispose() {
    _controller?.removeStatusListener(_onAnimationStatus);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final composition = widget.composition;
    final controller = _controller;

    return Scaffold(
      key: const ValueKey('loading'),
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: Center(
        child: composition != null && controller != null
            ? Lottie(
                composition: composition,
                controller: controller,
                width: _splashLottieSize,
                height: _splashLottieSize,
                fit: BoxFit.contain,
              )
            : Image.asset(
                'assets/imgs/logo_splash.png',
                width: _splashLogoWidth,
                fit: BoxFit.contain,
              ),
      ),
    );
  }
}
