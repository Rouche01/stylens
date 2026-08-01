import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';
import 'package:gostylens/core/config/dependency_injection.dart';
import 'package:gostylens/core/services/signed_url_service.dart';
import 'package:gostylens/models/remote_image.dart';
import 'package:gostylens/core/config/env_config.dart';

class ImageWithFallback extends StatefulWidget {
  final File? imageFile;
  final RemoteImage? remoteImage;
  final double width;
  final double height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? fallbackWidget;

  const ImageWithFallback({
    super.key,
    this.imageFile,
    this.remoteImage,
    this.width = 200,
    this.height = 200,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.fallbackWidget,
  });

  @override
  State<ImageWithFallback> createState() => _ImageWithFallbackState();
}

class _ImageWithFallbackState extends State<ImageWithFallback> {
  RemoteImage? _currentRemoteImage;
  bool _hasRetried = false;
  bool _imageReady = false;
  bool _loadFailed = false;

  static const _fadeDuration = Duration(milliseconds: 280);

  SignedUrlService get _signedUrls => locator<SignedUrlService>();

  @override
  void initState() {
    super.initState();
    _currentRemoteImage = widget.remoteImage;
    _seedSignedUrlCache(_currentRemoteImage);
  }

  @override
  void didUpdateWidget(ImageWithFallback oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.remoteImage != oldWidget.remoteImage) {
      setState(() {
        _currentRemoteImage = widget.remoteImage;
        _hasRetried = false;
        _imageReady = false;
        _loadFailed = false;
      });
      _seedSignedUrlCache(_currentRemoteImage);
    }
  }

  void _seedSignedUrlCache(RemoteImage? remote) {
    if (remote == null) return;
    if (remote.key.isEmpty || remote.url.isEmpty) return;
    _signedUrls.remember(remote.key, remote.url);
  }

  void _markImageReady() {
    if (_imageReady || !mounted) return;
    setState(() {
      _imageReady = true;
      _loadFailed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // If no image source provided, show fallback immediately
    if (widget.imageFile == null && _currentRemoteImage == null) {
      return _buildFallback(context);
    }

    Widget imageWidget;

    // Prioritize local file over URL for faster display
    if (widget.imageFile != null) {
      imageWidget = Image.file(
        widget.imageFile!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
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
    final resolvedUrl = EnvConfig.resolvePlatformUrl(remote.url);

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Always under the photo: BlurHash or quiet surface — never replaced mid-load.
          _buildPlaceholder(context, remote.blurHash),
          // Fade the sharp image in only after a decoded frame exists.
          AnimatedOpacity(
            opacity: _imageReady ? 1 : 0,
            duration: _fadeDuration,
            curve: Curves.easeOut,
            child: Image.network(
              resolvedUrl,
              key: ValueKey(resolvedUrl),
              width: widget.width,
              height: widget.height,
              fit: widget.fit,
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

  void _handleNetworkError(Object error, StackTrace? stackTrace) {
    if (!_hasRetried &&
        error is NetworkImageLoadException &&
        error.statusCode == 403) {
      _hasRetried = true;

      final imageKey =
          (_currentRemoteImage?.key != null &&
              _currentRemoteImage!.key.isNotEmpty)
          ? _currentRemoteImage!.key
          : _extractImageKey(_currentRemoteImage?.url ?? '');

      if (imageKey != null && imageKey.isNotEmpty) {
        _signedUrls
            .refresh(imageKey)
            .then((newUrl) {
              if (mounted) {
                setState(() {
                  _imageReady = false;
                  _loadFailed = false;
                  _currentRemoteImage = (_currentRemoteImage ??
                          RemoteImage(url: newUrl, key: imageKey))
                      .copyWith(url: newUrl, key: imageKey);
                });
              }
            })
            .catchError((e) {
              debugPrint('Signed URL refresh failed: $e');
              if (mounted) {
                setState(() {
                  _loadFailed = true;
                  _imageReady = false;
                });
              }
            });
        return;
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

  String? _extractImageKey(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    if (uri.pathSegments.isEmpty) return null;
    return uri.pathSegments.last;
  }
}
