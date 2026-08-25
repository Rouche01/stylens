import 'package:flutter/material.dart';
import 'package:gostylens/pages/intro/intro_colors.dart';

/// Intro slide 3 — feature grid + privacy banner.
class IntroFeaturesSlide extends StatefulWidget {
  const IntroFeaturesSlide({super.key, this.active = false});

  /// When true (page is visible), plays a grouped entrance.
  final bool active;

  @override
  State<IntroFeaturesSlide> createState() => _IntroFeaturesSlideState();
}

class _IntroFeaturesSlideState extends State<IntroFeaturesSlide>
    with SingleTickerProviderStateMixin {
  /// 0 = heading, 1 = feature cards, 2 = privacy.
  /// Overlapping windows so groups blend instead of popping in sequence.
  static const _stagger = 0.12;
  static const _span = 0.58;

  late final AnimationController _entrance;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 820),
    );
    if (widget.active) {
      _playEntrance();
    }
  }

  @override
  void didUpdateWidget(IntroFeaturesSlide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _playEntrance();
    }
    // Keep the settled frame visible while swiping away so Next/page
    // transitions don't flash empty content.
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
    super.dispose();
  }

  Animation<double> _groupAnim(int index) {
    final start = index * _stagger;
    final end = (start + _span).clamp(0.0, 1.0);
    return CurvedAnimation(
      parent: _entrance,
      curve: Interval(start, end, curve: Curves.easeInOutCubic),
    );
  }

  Widget _enter({required int index, required Widget child}) {
    final animation = _groupAnim(index);
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = animation.value;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - t)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = Color.lerp(scheme.secondary, scheme.primary, 0.5)!;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 540;
        final sectionGap = compact ? 16.0 : 24.0;
        final headlineSize = compact ? 30.0 : 34.0;

        return Padding(
          padding: EdgeInsets.fromLTRB(28, compact ? 12 : 20, 28, 0),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _enter(
                  index: 0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          style: TextStyle(
                            fontFamily: 'ClashDisplay',
                            fontSize: headlineSize,
                            fontWeight: FontWeight.w600,
                            height: 1.15,
                            letterSpacing: -0.6,
                            color: scheme.primary,
                          ),
                          children: [
                            const TextSpan(text: 'Dress like you\n'),
                            TextSpan(
                              text: 'meant it.',
                              style: TextStyle(
                                fontStyle: FontStyle.italic,
                                color: accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Outfit feedback, a smart closet, and style tips for every occasion, every day.',
                        style: TextStyle(
                          fontFamily: 'Metropolis',
                          fontSize: 14.5,
                          height: 1.45,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF5C635C),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: sectionGap),
                _enter(
                  index: 1,
                  child: const Column(
                    children: [
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _FeatureCard(
                                icon: Icons.chat_bubble_outline,
                                title: 'Outfit feedback',
                                body: 'Honest tips for any occasion',
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: _FeatureCard(
                                icon: Icons.checkroom_outlined,
                                title: 'Smart closet',
                                body: 'Your wardrobe, always with you',
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 12),
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _FeatureCard(
                                icon: Icons.auto_awesome_outlined,
                                title: 'Style Match',
                                body: 'Match inspo to what you own',
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: _FeatureCard(
                                icon: Icons.insights_outlined,
                                title: 'Gets smarter',
                                body: 'Learns your taste over time',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: sectionGap),
                _enter(
                  index: 2,
                  child: _PrivacyBanner(primary: scheme.primary),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PrivacyBanner extends StatelessWidget {
  const _PrivacyBanner({required this.primary});

  final Color primary;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: IntroColors.mintCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: IntroColors.forest.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.lock_outline,
              size: 18,
              color: primary,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Private by default',
                  style: TextStyle(
                    fontFamily: 'Metropolis',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: IntroColors.forest,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Your outfits stay yours. Never shared, never sold',
                  style: TextStyle(
                    fontFamily: 'Metropolis',
                    fontSize: 12,
                    height: 1.3,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF5C635C),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: IntroColors.cardShadow,
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: IntroColors.mintCard,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 18, color: primary),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Metropolis',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1F1A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: const TextStyle(
              fontFamily: 'Metropolis',
              fontSize: 12,
              height: 1.35,
              fontWeight: FontWeight.w400,
              color: Color(0xFF6B726A),
            ),
          ),
        ],
      ),
    );
  }
}
