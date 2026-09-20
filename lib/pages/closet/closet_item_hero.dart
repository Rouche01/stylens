import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';
import 'package:gostylens/core/config/env_config.dart';
import 'package:gostylens/models/closet_item.dart';
import 'package:gostylens/pages/closet/closet_item_hero_layout.dart';
import 'package:gostylens/widgets/image_with_fallback.dart';
import 'package:skeletonizer/skeletonizer.dart';

class ClosetItemHero extends StatefulWidget {
  const ClosetItemHero({
    super.key,
    required this.item,
    @visibleForTesting this.debugDecodedSize,
  });

  final ClosetItem item;

  /// Skips network decode so overlay tests can assert box vs no-box.
  @visibleForTesting
  final Size? debugDecodedSize;

  @override
  State<ClosetItemHero> createState() => _ClosetItemHeroState();
}

class _ClosetItemHeroState extends State<ClosetItemHero> {
  var _useAuth = false;
  Size? _decodedSize;
  ImageStream? _stream;
  ImageStreamListener? _listener;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _listenToImage();
  }

  @override
  void didUpdateWidget(ClosetItemHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id ||
        oldWidget.item.originalImageUrl != widget.item.originalImageUrl) {
      _useAuth = false;
      _decodedSize = null;
      _listenToImage();
    }
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  String? get _resolvedUrl {
    final url = widget.item.originalImageUrl;
    if (url == null || url.isEmpty) return null;
    return EnvConfig.resolvePlatformUrl(url);
  }

  void _detach() {
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
    _stream = null;
    _listener = null;
  }

  void _listenToImage() {
    if (widget.debugDecodedSize != null) {
      _detach();
      return;
    }
    final url = _resolvedUrl;
    if (url == null) {
      _detach();
      return;
    }

    final provider = NetworkImage(
      url,
      headers: _useAuth ? ImageWithFallback.authHeaders() : null,
    );
    final stream = provider.resolve(createLocalImageConfiguration(context));
    if (stream == _stream) return;

    _detach();
    _listener = ImageStreamListener(_onImage, onError: _onImageError);
    _stream = stream..addListener(_listener!);
  }

  void _onImage(ImageInfo info, bool synchronousCall) {
    final size = Size(
      info.image.width.toDouble(),
      info.image.height.toDouble(),
    );
    if (_decodedSize == size) return;
    _decodedSize = size;
    if (synchronousCall) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
      return;
    }
    if (mounted) setState(() {});
  }

  void _onImageError(Object error, StackTrace? stackTrace) {
    if (_useAuth) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _useAuth = true);
      _listenToImage();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final decodedSize = widget.debugDecodedSize ?? _decodedSize;
    final item = widget.item;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ClosetItemHeroLayout.horizontalInset,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ClosetItemHeroLayout.radius),
        child: AspectRatio(
          aspectRatio: ClosetItemHeroLayout.aspectRatio,
          child: ColoredBox(
            color: cs.primary,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _photo(cs),
                if (item.boundingBox != null && decodedSize != null)
                  Positioned.fill(
                    child: _overlay(cs, item.boundingBox!, decodedSize),
                  ),
                _caption(cs, item),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _photo(ColorScheme cs) {
    final url = _resolvedUrl;
    if (url == null) return _placeholder(cs);

    return Image.network(
      url,
      key: ValueKey('${widget.item.id}:$url:${_useAuth ? 'auth' : 'open'}'),
      headers: _useAuth ? ImageWithFallback.authHeaders() : null,
      gaplessPlayback: true,
      fit: BoxFit.cover,
      alignment: ClosetItemHeroLayout.imageAlignment,
      width: double.infinity,
      height: double.infinity,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) return child;
        return _placeholder(cs);
      },
      errorBuilder: (context, error, stackTrace) {
        if (!_useAuth) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() => _useAuth = true);
            _listenToImage();
          });
          return _placeholder(cs);
        }
        return _placeholder(cs);
      },
    );
  }

  Widget _placeholder(ColorScheme cs) {
    final blurHash = widget.item.blurHash;
    if (blurHash != null && blurHash.isNotEmpty) {
      return BlurHash(
        hash: blurHash,
        imageFit: BoxFit.cover,
        duration: Duration.zero,
      );
    }
    return ColoredBox(
      color: cs.primary.withValues(alpha: 0.92),
      child: const Skeletonizer.zone(
        child: Bone(width: double.infinity, height: double.infinity),
      ),
    );
  }

  Widget _overlay(ColorScheme cs, ClosetPercentBox box, Size decodedSize) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mapped = ClosetItemHeroLayout.percentBoxOnCoverFit(
          box: box,
          imageSize: decodedSize,
          widgetSize: constraints.biggest,
        );
        if (mapped == null) return const SizedBox.shrink();
        return CustomPaint(
          key: const ValueKey('closet-item-box-overlay'),
          size: constraints.biggest,
          painter: _ClosetItemBoxPainter(
            box: mapped,
            dimColor: const Color(
              0xFF1C221C,
            ).withValues(alpha: ClosetItemHeroLayout.dimOpacity),
            strokeColor: Color.lerp(cs.secondary, Colors.white, 0.12)!,
          ),
        );
      },
    );
  }

  Widget _caption(ColorScheme cs, ClosetItem item) {
    return Positioned(
      left: 14,
      right: 14,
      bottom: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            item.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'ClashDisplay',
              fontSize: 22,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.4,
              color: Colors.white,
              shadows: [
                Shadow(
                  color: Color(0x73000000),
                  blurRadius: 8,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Worn in this outfit',
            style: TextStyle(
              fontFamily: 'Metropolis',
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color.lerp(Colors.white, cs.secondary, 0.18),
              shadows: const [
                Shadow(
                  color: Color(0x73000000),
                  blurRadius: 8,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ClosetItemBoxPainter extends CustomPainter {
  const _ClosetItemBoxPainter({
    required this.box,
    required this.dimColor,
    required this.strokeColor,
  });

  final Rect box;
  final Color dimColor;
  final Color strokeColor;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = const Radius.circular(ClosetItemHeroLayout.boxRadius);
    final rounded = RRect.fromRectAndRadius(box, radius);
    final dim = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(rounded);
    canvas.drawPath(dim, Paint()..color = dimColor);
    canvas.drawRRect(
      rounded,
      Paint()
        ..color = strokeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = ClosetItemHeroLayout.boxStrokeWidth,
    );
  }

  @override
  bool shouldRepaint(covariant _ClosetItemBoxPainter oldDelegate) {
    return oldDelegate.box != box ||
        oldDelegate.dimColor != dimColor ||
        oldDelegate.strokeColor != strokeColor;
  }
}
