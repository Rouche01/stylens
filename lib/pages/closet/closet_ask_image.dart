import 'package:flutter/material.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';
import 'package:gostylens/core/config/env_config.dart';
import 'package:gostylens/core/managers/closet_manager.dart';
import 'package:gostylens/models/closet_pending_match.dart';
import 'package:provider/provider.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// Network crop for ask banner thumbs and the resolve sheet.
///
/// Shows a BlurHash (from the side or the matching closet tile) or a skeleton
/// until the first frame, then fades the photo in.
class ClosetAskNetworkImage extends StatelessWidget {
  const ClosetAskNetworkImage({
    super.key,
    required this.side,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  static const _fadeDuration = Duration(milliseconds: 280);

  final ClosetMatchSide side;
  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final url = side.thumbUrl;
    final fill = ColoredBox(color: cs.primary.withValues(alpha: 0.12));
    final blurHash = _blurHashFor(context, side);
    final placeholder = _placeholder(blurHash);

    if (url == null) {
      return SizedBox(
        width: width,
        height: height,
        child: blurHash == null ? fill : placeholder,
      );
    }

    return SizedBox(
      width: width,
      height: height,
      child: Image.network(
        EnvConfig.resolvePlatformUrl(url),
        width: width,
        height: height,
        fit: fit,
        gaplessPlayback: true,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded) return child;
          return Stack(
            fit: StackFit.expand,
            children: [
              placeholder,
              AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: _fadeDuration,
                curve: Curves.easeOut,
                child: child,
              ),
            ],
          );
        },
        errorBuilder: (context, error, stackTrace) => fill,
      ),
    );
  }

  static String? _blurHashFor(BuildContext context, ClosetMatchSide side) {
    final own = side.blurHash;
    if (own != null && own.isNotEmpty) return own;

    final id = side.closetItemId;
    if (id == null || id.isEmpty) return null;

    ClosetManager? manager;
    try {
      manager = Provider.of<ClosetManager>(context, listen: false);
    } on ProviderNotFoundException {
      manager = null;
    }
    final items = manager?.items;
    if (items == null) return null;
    for (final item in items) {
      if (item.id != id) continue;
      final hash = item.blurHash;
      if (hash != null && hash.isNotEmpty) return hash;
      return null;
    }
    return null;
  }

  static Widget _placeholder(String? blurHash) {
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
}
