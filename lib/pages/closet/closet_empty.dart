import 'package:flutter/material.dart';
import 'package:gostylens/widgets/primary_button.dart';

/// First-run empty closet: small ghost-rack illustration, invite copy, capture CTA.
class ClosetEmptyState extends StatelessWidget {
  const ClosetEmptyState({super.key, required this.onCaptureOutfit});

  final VoidCallback onCaptureOutfit;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ExcludeSemantics(child: _EmptyGhostRack()),
            const SizedBox(height: 18),
            Text(
              'Your closet is empty',
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
              'Capture an outfit and we’ll pull the pieces out for you. '
              'Shirts, jeans, shoes, the lot.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Metropolis',
                fontSize: 14,
                height: 1.45,
                color: cs.primary.withValues(alpha: 0.58),
              ),
            ),
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
  });

  final double bottomPad;
  final VoidCallback onCaptureOutfit;

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(32, 0, 32, bottomPad),
        child: ClosetEmptyState(onCaptureOutfit: onCaptureOutfit),
      ),
    );
  }
}

class _EmptyGhostRack extends StatelessWidget {
  const _EmptyGhostRack();

  static const _heights = [70.0, 88.0, 62.0];
  static const _tileWidth = 52.0;
  static const _radius = 12.0;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fill = cs.primary.withValues(alpha: 0.06);
    final stroke = cs.primary.withValues(alpha: 0.22);

    return SizedBox(
      height: 88,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < _heights.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            CustomPaint(
              size: Size(_tileWidth, _heights[i]),
              painter: _DashedRRectPainter(
                fill: fill,
                stroke: stroke,
                radius: _radius,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  const _DashedRRectPainter({
    required this.fill,
    required this.stroke,
    required this.radius,
  });

  final Color fill;
  final Color stroke;
  final double radius;

  static const _dash = 5.0;
  static const _gap = 3.5;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0.75, 0.75, size.width - 1.5, size.height - 1.5),
      Radius.circular(radius),
    );
    canvas.drawRRect(rrect, Paint()..color = fill);

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
        oldDelegate.radius != radius;
  }
}
