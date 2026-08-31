import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

/// Shell-scoped pose video for the Capture tab.
///
/// Keeps a single [VideoPlayerController] alive across tab switches so Android
/// does not recreate the texture on every visit to Capture.
class PoseVideoService extends ChangeNotifier {
  static const videoAsset = 'assets/videos/strike_a_pose.mp4';
  static const posterAsset = 'assets/imgs/capture/strike_a_pose_poster.jpg';

  VideoPlayerController? _controller;
  var _ready = false;
  var _syncingPlayback = false;
  Future<void>? _initializeFuture;

  VideoPlayerController? get controller => _controller;
  bool get isReady => _ready;

  Future<void> ensureInitialized() {
    if (_ready) return Future.value();
    return _initializeFuture ??= _initialize();
  }

  Future<void> _initialize() async {
    final controller = VideoPlayerController.asset(
      videoAsset,
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
      debugPrint('PoseVideoService failed to load: $e\n$stackTrace');
      await controller.dispose();
      _initializeFuture = null;
      return;
    }

    _controller = controller;
    _ready = true;
    notifyListeners();
  }

  /// Pauses or resumes without seeking — avoids a visible jump on tab return.
  Future<void> setPlayback({required bool shouldPlay}) async {
    if (_syncingPlayback) return;

    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    _syncingPlayback = true;
    try {
      if (!shouldPlay) {
        if (controller.value.isPlaying) {
          await controller.pause();
        }
        return;
      }

      if (!controller.value.isPlaying) {
        await controller.play();
      }
    } finally {
      _syncingPlayback = false;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _controller = null;
    _ready = false;
    super.dispose();
  }
}
