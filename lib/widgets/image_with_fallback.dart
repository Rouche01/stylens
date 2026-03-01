import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:gostylens/models/remote_image.dart';

Future<String> regenerateImageUrl(String imageKey) async {
  try {
    final presignedUrlRes = await http.get(
      Uri.parse(
        "${dotenv.env['API_BASE_URL']}/assets/download-url?filename=$imageKey",
      ),
      headers: {"Content-Type": "application/json"},
    );

    if (presignedUrlRes.statusCode != 200) {
      throw Exception("Failed to get upload URL");
    }

    return presignedUrlRes.body;
  } catch (e) {
    print('Error uploading image: $e');
    return '';
  }
}

class ImageWithFallback extends StatefulWidget {
  final File? imageFile;
  final RemoteImage? remoteImage;
  final double width;
  final double height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? fallbackWidget;

  static final Map<String, String> _imageUrlCache = {};

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

Future<String> getCachedOrRegenerateUrl(String imageKey) async {
  if (ImageWithFallback._imageUrlCache.containsKey(imageKey)) {
    return ImageWithFallback._imageUrlCache[imageKey]!;
  }
  final newUrl = await regenerateImageUrl(imageKey);
  if (newUrl.isNotEmpty) {
    ImageWithFallback._imageUrlCache[imageKey] = newUrl;
  }
  return newUrl;
}

class _ImageWithFallbackState extends State<ImageWithFallback> {
  RemoteImage? _currentRemoteImage;
  bool _hasRetried = false;

  @override
  void initState() {
    super.initState();
    _currentRemoteImage = widget.remoteImage;
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
      imageWidget = Image.network(
        _currentRemoteImage!.url,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: widget.width,
            height: widget.height,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                    : null,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) =>
            _handleNetworkError(context, error, stackTrace),
      );
    }

    if (widget.borderRadius != null) {
      return ClipRRect(borderRadius: widget.borderRadius!, child: imageWidget);
    }

    return imageWidget;
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

  Widget _buildErrorWidget(
    BuildContext context,
    Object error,
    StackTrace? stackTrace,
  ) {
    print('Error loading image: $error');

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

  Widget _handleNetworkError(
    BuildContext context,
    Object error,
    StackTrace? stackTrace,
  ) {
    // Only retry once if error is 403
    if (!_hasRetried &&
        error is NetworkImageLoadException &&
        error.statusCode == 403) {
      _hasRetried = true;

      final imageKey =
          (_currentRemoteImage?.key != null &&
              _currentRemoteImage!.key.isNotEmpty)
          ? _currentRemoteImage!.key
          : _extractImageKey(_currentRemoteImage?.url ?? '');

      if (imageKey != null) {
        getCachedOrRegenerateUrl(imageKey).then((newUrl) {
          if (mounted) {
            setState(() {
              _currentRemoteImage = RemoteImage(url: newUrl, key: imageKey);
            });
          }
        });
        // Show loading indicator while retrying
        return Container(
          width: widget.width,
          height: widget.height,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Center(child: CircularProgressIndicator()),
        );
      }
    }
    return _buildErrorWidget(context, error, stackTrace);
  }

  String? _extractImageKey(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    if (uri.pathSegments.isEmpty) return null;
    return uri.pathSegments.last;
  }
}
