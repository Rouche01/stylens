import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:gostylens/widgets/floating_nav_bar.dart';
import 'package:gostylens/widgets/primary_button.dart';

enum ClosetEmptyKind { idle, processing, failed }

/// First-run empty, in-flight wait, or failed wave with nothing to show.
class ClosetEmptyState extends StatelessWidget {
  const ClosetEmptyState({
    super.key,
    required this.onCaptureOutfit,
    this.kind = ClosetEmptyKind.idle,
  });

  final VoidCallback onCaptureOutfit;
  final ClosetEmptyKind kind;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final processing = kind == ClosetEmptyKind.processing;
    final failed = kind == ClosetEmptyKind.failed;
    final title = processing
        ? 'Hanging your pieces'
        : failed
        ? 'Couldn’t hang that look'
        : 'Nothing hanging yet';
    final body = processing
        ? 'We’re pulling them from your outfit. They’ll land here in a moment.'
        : failed
        ? 'We couldn’t pull pieces from your latest outfit. '
              'Capture it again and we’ll try once more.'
        : 'Capture an outfit and we’ll pull the pieces out for you. '
              'Shirts, jeans, shoes, the lot.';

    return Semantics(
      liveRegion: processing || failed,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(child: _EmptyGhostRack(shimmer: processing)),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'ClashDisplay',
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                  color: cs.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                body,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Metropolis',
                  fontSize: 14,
                  height: 1.45,
                  color: cs.primary.withValues(alpha: 0.58),
                ),
              ),
              if (!processing) ...[
                const SizedBox(height: 22),
                SizedBox(
                  height: 44,
                  width: double.infinity,
                  child: PrimaryButton(
                    label: 'Capture an outfit',
                    onPressed: onCaptureOutfit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: cs.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// [ClosetEmptyState] sized to fill the remaining closet browse scroll view.
class ClosetEmptySliver extends StatelessWidget {
  const ClosetEmptySliver({
    super.key,
    required this.bottomPad,
    required this.onCaptureOutfit,
    this.kind = ClosetEmptyKind.idle,
  });

  final double bottomPad;
  final VoidCallback onCaptureOutfit;
  final ClosetEmptyKind kind;

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(32, 0, 32, bottomPad),
        child: ClosetEmptyState(onCaptureOutfit: onCaptureOutfit, kind: kind),
      ),
    );
  }
}

/// Non-tappable wait chip pinned above the floating dock.
class ClosetProcessingDockChip extends StatelessWidget {
  const ClosetProcessingDockChip({super.key});

  static const double sideInset = 20;
  static const double gapAboveDock = 8;
  static const double height = 52;

  static double bottomOffset(BuildContext context) {
    return FloatingNavBar.contentBottomInset(context) + gapAboveDock;
  }

  static double scrollReserve(BuildContext context) {
    return gapAboveDock + height;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Semantics(
      liveRegion: true,
      label: 'Hanging a few more. From your latest outfit',
      child: IgnorePointer(
        child: Material(
          color: Colors.white,
          elevation: 0,
          shadowColor: cs.primary.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(22),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 320),
            padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: cs.primary.withValues(alpha: 0.16),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _LimeSpinnerMark(),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hanging a few more',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Metropolis',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: cs.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'From your latest outfit',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Metropolis',
                          fontSize: 12,
                          color: cs.primary.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
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

class _LimeSpinnerMark extends StatelessWidget {
  const _LimeSpinnerMark();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Color.lerp(cs.secondary, Colors.white, 0.3),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const SizedBox(
        width: 36,
        height: 36,
        child: Center(child: _LimeSpinner()),
      ),
    );
  }
}

class _LimeSpinner extends StatelessWidget {
  const _LimeSpinner();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final reduceMotion = FloatingNavBar.reduceMotionOf(context);

    return SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(
        strokeWidth: 2.2,
        color: cs.primary,
        backgroundColor: cs.primary.withValues(alpha: 0.18),
        value: reduceMotion ? 0.7 : null,
      ),
    );
  }
}

class _EmptyGhostRack extends StatefulWidget {
  const _EmptyGhostRack({this.shimmer = false});

  final bool shimmer;

  static const _heights = [70.0, 88.0, 62.0];
  static const _tileWidth = 52.0;
  static const _radius = 12.0;
  static const _stagger = [0.0, 0.08, 0.16];

  @override
  State<_EmptyGhostRack> createState() => _EmptyGhostRackState();
}

class _EmptyGhostRackState extends State<_EmptyGhostRack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant _EmptyGhostRack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shimmer != widget.shimmer) _syncAnimation();
  }

  void _syncAnimation() {
    final animate = widget.shimmer && !FloatingNavBar.reduceMotionOf(context);
    if (animate) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final animate = widget.shimmer && !FloatingNavBar.reduceMotionOf(context);
    final baseFill = cs.primary.withValues(alpha: 0.06);
    final fill = animate ? Color.lerp(baseFill, cs.secondary, 0.34)! : baseFill;
    final stroke = animate
        ? Color.lerp(cs.primary.withValues(alpha: 0.22), cs.secondary, 0.45)!
        : cs.primary.withValues(alpha: 0.22);
    final highlight = Color.lerp(fill, cs.secondary, 1)!;

    return SizedBox(
      height: 88,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < _EmptyGhostRack._heights.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            RepaintBoundary(
              child: _GhostTile(
                size: Size(
                  _EmptyGhostRack._tileWidth,
                  _EmptyGhostRack._heights[i],
                ),
                fill: fill,
                stroke: stroke,
                highlight: highlight,
                shimmer: animate ? _controller : null,
                stagger: _EmptyGhostRack._stagger[i],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GhostTile extends StatelessWidget {
  const _GhostTile({
    required this.size,
    required this.fill,
    required this.stroke,
    required this.highlight,
    required this.shimmer,
    required this.stagger,
  });

  final Size size;
  final Color fill;
  final Color stroke;
  final Color highlight;
  final Animation<double>? shimmer;
  final double stagger;

  @override
  Widget build(BuildContext context) {
    final painter = _DashedRRectPainter(
      fill: fill,
      stroke: stroke,
      highlight: highlight,
      radius: _EmptyGhostRack._radius,
    );

    if (shimmer == null) {
      return CustomPaint(size: size, painter: painter);
    }

    return AnimatedBuilder(
      animation: shimmer!,
      builder: (context, _) {
        return CustomPaint(
          size: size,
          painter: _DashedRRectPainter(
            fill: fill,
            stroke: stroke,
            highlight: highlight,
            radius: _EmptyGhostRack._radius,
            shimmerT: _sweep(shimmer!.value, stagger),
          ),
        );
      },
    );
  }

  /// Linear sweep for most of the loop, then rest off-screen so the wrap is hidden.
  static double _sweep(double value, double stagger) {
    var t = value - stagger;
    t -= t.floorToDouble();
    const travel = 0.82;
    if (t >= travel) return 1;
    return t / travel;
  }
}

class _DashedRRectPainter extends CustomPainter {
  const _DashedRRectPainter({
    required this.fill,
    required this.stroke,
    required this.radius,
    this.highlight,
    this.shimmerT,
  });

  final Color fill;
  final Color stroke;
  final Color? highlight;
  final double radius;
  final double? shimmerT;

  static const _dash = 5.0;
  static const _gap = 3.5;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0.75, 0.75, size.width - 1.5, size.height - 1.5),
      Radius.circular(radius),
    );

    final fillPaint = Paint()..color = fill;
    final t = shimmerT;
    final glow = highlight;
    if (t != null && glow != null) {
      final band = size.width * 1.5;
      final x = ui.lerpDouble(-band, size.width, t)!;
      fillPaint.shader = ui.Gradient.linear(
        Offset(x, 0),
        Offset(x + band, size.height * 0.2),
        [
          fill,
          Color.lerp(fill, glow, 0.7)!,
          glow,
          Color.lerp(fill, glow, 0.7)!,
          fill,
        ],
        const [0.0, 0.2, 0.5, 0.8, 1.0],
      );
    }
    canvas.drawRRect(rrect, fillPaint);

    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = stroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      var draw = true;
      while (distance < metric.length) {
        final extent = draw ? _dash : _gap;
        final next = (distance + extent).clamp(0.0, metric.length);
        if (draw) {
          canvas.drawPath(metric.extractPath(distance, next), paint);
        }
        distance = next;
        draw = !draw;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) {
    return oldDelegate.fill != fill ||
        oldDelegate.stroke != stroke ||
        oldDelegate.radius != radius ||
        oldDelegate.highlight != highlight ||
        oldDelegate.shimmerT != shimmerT;
  }
}
