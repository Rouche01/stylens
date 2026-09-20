import 'package:flutter/material.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';
import 'package:gostylens/core/config/env_config.dart';
import 'package:gostylens/models/closet_item.dart';
import 'package:gostylens/pages/closet/closet_browse_layout.dart';
import 'package:gostylens/widgets/image_with_fallback.dart';
import 'package:skeletonizer/skeletonizer.dart';

class ClosetItemTile extends StatelessWidget {
  const ClosetItemTile({super.key, required this.item, this.onTap});

  final ClosetItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return RepaintBoundary(
      child: _PressableScale(
        onTap: onTap,
        child: ClipRRect(
          clipBehavior: Clip.hardEdge,
          borderRadius: BorderRadius.circular(ClosetBrowseLayout.tileRadius),
          child: AspectRatio(
            aspectRatio: item.aspectRatio,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _ClosetTileImage(item: item),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          cs.primary.withValues(alpha: 0.72),
                        ],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 20, 10, 9),
                      child: Text(
                        item.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Metropolis',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ClosetSkeletonTile extends StatelessWidget {
  const ClosetSkeletonTile({super.key, required this.aspectRatio});

  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(ClosetBrowseLayout.tileRadius),
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: ColoredBox(color: cs.primary.withValues(alpha: 0.08)),
      ),
    );
  }
}

class _PressableScale extends StatefulWidget {
  const _PressableScale({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<_PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<_PressableScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

Widget _tilePlaceholder(String? blurHash) {
  if (blurHash != null && blurHash.isNotEmpty) {
    return BlurHash(
      hash: blurHash,
      imageFit: BoxFit.cover,
      duration: Duration.zero,
    );
  }
  return const Skeletonizer.zone(
    child: Bone(width: double.infinity, height: double.infinity),
  );
}

class _ClosetTileImage extends StatefulWidget {
  const _ClosetTileImage({required this.item});

  final ClosetItem item;

  @override
  State<_ClosetTileImage> createState() => _ClosetTileImageState();
}

class _ClosetTileImageState extends State<_ClosetTileImage> {
  var _useAuth = false;

  @override
  void didUpdateWidget(_ClosetTileImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id ||
        oldWidget.item.tileImageUrl != widget.item.tileImageUrl) {
      _useAuth = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final cs = Theme.of(context).colorScheme;
    final placeholder = ColoredBox(
      color: cs.primary.withValues(alpha: 0.12),
      child: Icon(
        Icons.checkroom_outlined,
        color: cs.primary.withValues(alpha: 0.35),
      ),
    );

    final isolateUrl = item.tileImageUrl;
    if (isolateUrl == null) return placeholder;

    final url = EnvConfig.resolvePlatformUrl(isolateUrl);
    final headers = _useAuth ? ImageWithFallback.authHeaders() : null;

    return Image.network(
      url,
      key: ValueKey('${item.id}:$url:${_useAuth ? 'auth' : 'open'}'),
      headers: headers,
      gaplessPlayback: true,
      fit: BoxFit.fitWidth,
      alignment: Alignment.topCenter,
      width: double.infinity,
      height: double.infinity,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) return child;
        return _tilePlaceholder(item.blurHash);
      },
      errorBuilder: (context, error, stackTrace) {
        if (!_useAuth) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _useAuth = true);
          });
          return _tilePlaceholder(item.blurHash);
        }
        return placeholder;
      },
    );
  }
}
