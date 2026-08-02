import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';
import 'package:gostylens/core/config/dependency_injection.dart';
import 'package:gostylens/core/config/env_config.dart';
import 'package:gostylens/models/remote_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ImageWithFallback extends StatefulWidget {
  /// Top-biased cover crop for full-body outfit shots (keeps faces in frame).
  static const Alignment outfitCoverAlignment = Alignment(0, -0.45);

  final File? imageFile;
  final RemoteImage? remoteImage;
  final double width;
  final double height;
  final BoxFit fit;
  final Alignment alignment;
  final BorderRadius? borderRadius;
  final Widget? fallbackWidget;

  const ImageWithFallback({
    super.key,
    this.imageFile,
    this.remoteImage,
    this.width = 200,
    this.height = 200,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.borderRadius,
    this.fallbackWidget,
  });

  /// Authenticated Worker proxy URL for an R2 object key.
  static String proxyUrlForKey(String key) {
    final base = EnvConfig.apiBaseUrl.replaceAll(RegExp(r'/+$'), '');
    return '$base/assets/file?key=${Uri.encodeQueryComponent(key)}';
  }

  @override
  State<ImageWithFallback> createState() => _ImageWithFallbackState();
}

class _ImageWithFallbackState extends State<ImageWithFallback> {
  RemoteImage? _currentRemoteImage;
  bool _hasRetriedAuth = false;
  bool _imageReady = false;
  bool _loadFailed = false;
  /// Bumped after token refresh so Image.network reloads with new headers.
  int _authGeneration = 0;

  static const _fadeDuration = Duration(milliseconds: 280);

  @override
  void initState() {
    super.initState();
    _currentRemoteImage = widget.remoteImage;
  }

  @override
  void didUpdateWidget(ImageWithFallback oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.remoteImage != oldWidget.remoteImage) {
      setState(() {
        _currentRemoteImage = widget.remoteImage;
        _hasRetriedAuth = false;
        _imageReady = false;
        _loadFailed = false;
      });
    }
  }

  void _markImageReady() {
    if (_imageReady || !mounted) return;
    setState(() {
      _imageReady = true;
      _loadFailed = false;
    });
  }

  /// Prefer key → proxy URL so we never depend on stored R2 presigns.
  String _displayUrl(RemoteImage remote) {
    if (remote.key.isNotEmpty) {
      return EnvConfig.resolvePlatformUrl(
        ImageWithFallback.proxyUrlForKey(remote.key),
      );
    }
    return EnvConfig.resolvePlatformUrl(remote.url);
  }

  Map<String, String>? _authHeaders() {
    final token =
        locator<SupabaseClient>().auth.currentSession?.accessToken;
    if (token == null || token.isEmpty) return null;
    return {'Authorization': 'Bearer $token'};
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageFile == null && _currentRemoteImage == null) {
      return _buildFallback(context);
    }

    Widget imageWidget;

    if (widget.imageFile != null) {
      imageWidget = Image.file(
        widget.imageFile!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        alignment: widget.alignment,
        errorBuilder: (context, error, stackTrace) =>
            _buildErrorWidget(context, error, stackTrace),
      );
    } else {
      imageWidget = _buildNetworkImage(context);
    }

    if (widget.borderRadius != null) {
      return ClipRRect(borderRadius: widget.borderRadius!, child: imageWidget);
    }

    return imageWidget;
  }

  Widget _buildNetworkImage(BuildContext context) {
    final remote = _currentRemoteImage!;
    final resolvedUrl = _displayUrl(remote);
    final headers = _authHeaders();

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildPlaceholder(context, remote.blurHash),
          AnimatedOpacity(
            opacity: _imageReady ? 1 : 0,
            duration: _fadeDuration,
            curve: Curves.easeOut,
            child: Image.network(
              resolvedUrl,
              key: ValueKey('$resolvedUrl#$_authGeneration'),
              width: widget.width,
              height: widget.height,
              fit: widget.fit,
              alignment: widget.alignment,
              headers: headers,
              gaplessPlayback: true,
              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                if (!_imageReady &&
                    (wasSynchronouslyLoaded || frame != null)) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _markImageReady();
                  });
                }
                return child;
              },
              errorBuilder: (context, error, stackTrace) {
                _scheduleNetworkError(error, stackTrace);
                return const SizedBox.shrink();
              },
            ),
          ),
          if (_loadFailed)
            AnimatedOpacity(
              opacity: 1,
              duration: _fadeDuration,
              child: _buildErrorOverlay(context),
            ),
        ],
      ),
    );
  }

  void _scheduleNetworkError(Object error, StackTrace? stackTrace) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _handleNetworkError(error, stackTrace);
    });
  }

  Widget _buildPlaceholder(BuildContext context, String? blurHash) {
    if (blurHash != null && blurHash.isNotEmpty) {
      return BlurHash(
        hash: blurHash,
        imageFit: widget.fit,
        duration: Duration.zero,
      );
    }

    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
    );
  }

  Widget _buildFallback(BuildContext context) {
    if (widget.fallbackWidget != null) {
      Widget result = widget.fallbackWidget!;
      if (widget.borderRadius != null) {
        result = ClipRRect(borderRadius: widget.borderRadius!, child: result);
      }
      return result;
    }

    return _buildDefaultFallback(context);
  }

  Widget _buildErrorOverlay(BuildContext context) {
    if (widget.fallbackWidget != null) {
      return widget.fallbackWidget!;
    }
    return _buildDefaultFallback(context);
  }

  Widget _buildErrorWidget(
    BuildContext context,
    Object error,
    StackTrace? stackTrace,
  ) {
    debugPrint('Error loading image: $error');

    if (widget.fallbackWidget != null) {
      return _buildFallback(context);
    }

    return _buildDefaultFallback(context);
  }

  Widget _buildDefaultFallback(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image,
            size: widget.width > 100 ? 48 : 24,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          if (widget.width > 100) ...[
            SizedBox(height: 8),
            Text(
              'Image unavailable',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _handleNetworkError(Object error, StackTrace? stackTrace) async {
    // Proxy uses Bearer auth — refresh JWT once on 401, then reload image.
    if (!_hasRetriedAuth &&
        error is NetworkImageLoadException &&
        error.statusCode == 401) {
      _hasRetriedAuth = true;
      try {
        await locator<SupabaseClient>().auth.refreshSession();
        if (mounted) {
          setState(() {
            _imageReady = false;
            _loadFailed = false;
            _authGeneration++;
          });
        }
        return;
      } catch (e) {
        debugPrint('Auth refresh for image failed: $e');
      }
    }

    debugPrint('Error loading image: $error');
    if (mounted) {
      setState(() {
        _loadFailed = true;
        _imageReady = false;
      });
    }
  }
}
