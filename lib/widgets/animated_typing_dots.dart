import 'package:flutter/material.dart';

class AnimatedTypingDots extends StatefulWidget {
  final double size;
  final Color color;
  const AnimatedTypingDots({
    this.size = 12,
    this.color = Colors.grey,
    super.key,
  });

  @override
  State<AnimatedTypingDots> createState() => _AnimatedTypingDotsState();
}

class _AnimatedTypingDotsState extends State<AnimatedTypingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<Animation<double>> _animations;

  static const double _dotVerticalMovementFactor = 0.5;
  static const double _dotDelayFraction = 0.18; // how much each dot is delayed
  static const double _dotAnimFraction = 0.68; // how long each dot animates
  static const double _dotPauseFraction = 0.14; // pause after each dot animates

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    )..repeat();

    // Add a pause after each dot's animation
    _animations = List.generate(3, (i) {
      final start = i * _dotDelayFraction;
      final end = start + _dotAnimFraction;
      final pauseEnd = end + _dotPauseFraction;
      return TweenSequence([
        TweenSequenceItem(
          tween: Tween<double>(
            begin: 0.0,
            end: -widget.size * _dotVerticalMovementFactor,
          ).chain(CurveTween(curve: Curves.easeInOutCubic)),
          weight: 50,
        ),
        TweenSequenceItem(
          tween: Tween<double>(
            begin: -widget.size * _dotVerticalMovementFactor,
            end: 0.0,
          ).chain(CurveTween(curve: Curves.easeInOutCubic)),
          weight: 50,
        ),
        // Pause at origin
        TweenSequenceItem(tween: ConstantTween<double>(0.0), weight: 20),
      ]).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(
            start,
            pauseEnd > 1.0 ? 1.0 : pauseEnd,
            curve: Curves.linear,
          ),
        ),
      );
    });
  }

  Color _getDeeperColor(Color color) {
    final hsl = HSLColor.fromColor(color);
    final deeper = hsl.withLightness((hsl.lightness - 0.18).clamp(0.0, 1.0));
    return deeper.toColor();
  }

  Color _interpolateColor(double t) {
    final base = widget.color;
    final deep = _getDeeperColor(base);
    if (t <= 0.5) {
      return Color.lerp(base, deep, t * 2)!;
    } else {
      return Color.lerp(deep, base, (t - 0.5) * 2)!;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size * 5,
      height: widget.size * 2,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (i) {
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final anim = _animations[i];
              final totalDistance = -widget.size * _dotVerticalMovementFactor;
              final progress = anim.value / totalDistance;
              final t = progress.isNaN ? 0.0 : progress.abs().clamp(0.0, 1.0);

              return Transform.translate(
                offset: Offset(0, anim.value),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: widget.size * 0.3),
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      color: _interpolateColor(t),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}
