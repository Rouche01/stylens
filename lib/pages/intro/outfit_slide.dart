import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

/// Intro slide 1 — dark outfit feedback hero.
class IntroOutfitSlide extends StatefulWidget {
  const IntroOutfitSlide({super.key, this.active = false});

  /// When true (page is visible), plays hero + tag entrances.
  final bool active;

  @override
  State<IntroOutfitSlide> createState() => _IntroOutfitSlideState();
}

class _IntroOutfitSlideState extends State<IntroOutfitSlide>
    with TickerProviderStateMixin {
  late final AnimationController _entrance;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 980),
    );
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );
    if (widget.active) {
      _playEntrance();
      _pulse.repeat();
    }
  }

  @override
  void didUpdateWidget(IntroOutfitSlide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _playEntrance();
      _pulse.repeat();
    } else if (!widget.active && oldWidget.active) {
      // Keep hero visible during exit; only pause the ring pulse.
      _pulse.stop();
    }
  }

  void _playEntrance() {
    _entrance.value = 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.active) return;
      _entrance.forward();
    });
  }

  @override
  void dispose() {
    _entrance.dispose();
    _pulse.dispose();
    super.dispose();
  }

  Animation<double> _interval(double begin, double end) {
    return CurvedAnimation(
      parent: _entrance,
      curve: Interval(begin, end, curve: Curves.easeOutCubic),
    );
  }

  @override
  Widget build(BuildContext context) {
    final portrait = _interval(0.0, 0.42);
    final tag0 = _interval(0.28, 0.58);
    final tag1 = _interval(0.40, 0.70);
    final tag2 = _interval(0.52, 0.82);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxHeight < 520;
          final heroHeight = compact ? 210.0 : 280.0;
          final headlineSize = compact ? 30.0 : 36.0;

          return Column(
            children: [
              const Spacer(flex: 2),
              _OutfitHero(
                height: heroHeight,
                portrait: portrait,
                pulse: _pulse,
                tagAnimations: [tag0, tag1, tag2],
              ),
              const Spacer(flex: 2),
              Text.rich(
                TextSpan(
                  style: TextStyle(
                    fontFamily: 'ClashDisplay',
                    fontSize: headlineSize,
                    fontWeight: FontWeight.w600,
                    height: 1.15,
                    letterSpacing: -0.6,
                    color: Colors.white,
                  ),
                  children: [
                    const TextSpan(text: 'What are you\nwearing '),
                    TextSpan(
                      text: 'today?',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Share your outfit and get honest, specific tips for wherever you\'re headed.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Metropolis',
                  fontSize: compact ? 14 : 15,
                  height: 1.45,
                  fontWeight: FontWeight.w400,
                  color: Colors.white.withValues(alpha: 0.78),
                ),
              ),
              const Spacer(flex: 3),
            ],
          );
        },
      ),
    );
  }
}

class _OutfitHero extends StatelessWidget {
  const _OutfitHero({
    required this.height,
    required this.portrait,
    required this.pulse,
    required this.tagAnimations,
  });

  final double height;
  final Animation<double> portrait;
  final Animation<double> pulse;
  final List<Animation<double>> tagAnimations;

  @override
  Widget build(BuildContext context) {
    final scale = height / 280.0;

    return SizedBox(
      height: height,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: pulse,
        builder: (context, child) {
          return CustomPaint(
            painter: _ConcentricRingsPainter(pulse: pulse.value),
            child: child,
          );
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: portrait,
              builder: (context, child) {
                final t = portrait.value;
                return Opacity(
                  opacity: t,
                  child: Transform.scale(
                    scale: 0.92 + 0.08 * t,
                    child: child,
                  ),
                );
              },
              child: SizedBox(
                width: 150 * scale,
                height: 210 * scale,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.55),
                      width: 1.5,
                    ),
                  ),
                  child: Padding(
                    // Keep the photo inside the stroke so corners match the frame.
                    padding: const EdgeInsets.all(1.5),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: Image.asset(
                        // Unsplash — full-body outfit photo (photo-1545291730-faff8ca1d4b0)
                        'assets/imgs/intro/outfit_hero.jpg',
                        fit: BoxFit.cover,
                        alignment: const Alignment(0, -0.15),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 36 * scale,
              left: 8 * scale,
              child: _EnterTag(
                animation: tagAnimations[0],
                from: const Offset(-18, 0),
                child: const _GlassTag(label: '✓  Evening ready'),
              ),
            ),
            Positioned(
              top: 110 * scale,
              right: 0,
              child: _EnterTag(
                animation: tagAnimations[1],
                from: const Offset(18, 0),
                child: const _GlassTag(label: 'Add a blazer'),
              ),
            ),
            Positioned(
              bottom: 42 * scale,
              left: 24 * scale,
              child: _EnterTag(
                animation: tagAnimations[2],
                from: const Offset(-18, 8),
                child: const _GlassTag(label: 'Love the jumpsuit ✨'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EnterTag extends StatelessWidget {
  const _EnterTag({
    required this.animation,
    required this.from,
    required this.child,
  });

  final Animation<double> animation;
  final Offset from;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = animation.value;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(from.dx * (1 - t), from.dy * (1 - t)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _GlassTag extends StatelessWidget {
  const _GlassTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'Metropolis',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _ConcentricRingsPainter extends CustomPainter {
  const _ConcentricRingsPainter({required this.pulse});

  /// 0→1 loop; each ring is phase-offset for an outward ripple.
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    for (var i = 1; i <= 5; i++) {
      final phase = (pulse + i * 0.14) % 1.0;
      final wave = (math.sin(phase * math.pi * 2) + 1) / 2; // 0→1→0
      final base = 40.0 + i * 28;
      final radius = base * (1 + 0.035 * wave);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.04 + 0.07 * wave);

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ConcentricRingsPainter oldDelegate) =>
      oldDelegate.pulse != pulse;
}
