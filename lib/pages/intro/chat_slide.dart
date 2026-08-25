import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:gostylens/pages/intro/intro_colors.dart';

/// Intro slide 2 — snap / chat / step out mock conversation.
class IntroChatSlide extends StatefulWidget {
  const IntroChatSlide({super.key, this.active = false});

  /// When true (page is visible), plays the staggered bubble entrance.
  final bool active;

  @override
  State<IntroChatSlide> createState() => _IntroChatSlideState();
}

class _IntroChatSlideState extends State<IntroChatSlide>
    with SingleTickerProviderStateMixin {
  static const _stagger = 0.11;
  static const _span = 0.42;

  late final AnimationController _entrance;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 780),
    );
    if (widget.active) {
      _entrance.forward();
    }
  }

  @override
  void didUpdateWidget(IntroChatSlide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _entrance.forward(from: 0);
    }
    // Keep the settled frame visible while swiping away so Next/page
    // transitions don't flash empty content.
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  Animation<double> _bubbleAnim(int index) {
    final start = index * _stagger;
    final end = (start + _span).clamp(0.0, 1.0);
    return CurvedAnimation(
      parent: _entrance,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
  }

  Widget _enter({required int index, required Widget child}) {
    final animation = _bubbleAnim(index);
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = animation.value;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - t)),
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
    // Secondary alone is too light on cream; lean toward primary for contrast.
    final chatAccent = Color.lerp(scheme.secondary, scheme.primary, 0.5)!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxHeight < 520;
          final headlineSize = compact ? 32.0 : 40.0;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  style: TextStyle(
                    fontFamily: 'ClashDisplay',
                    fontSize: headlineSize,
                    fontWeight: FontWeight.w600,
                    height: 1.12,
                    letterSpacing: -0.8,
                    color: scheme.primary,
                  ),
                  children: [
                    const TextSpan(text: 'Snap.\n'),
                    TextSpan(
                      text: 'Chat.\n',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: chatAccent,
                      ),
                    ),
                    const TextSpan(text: 'Step out.'),
                  ],
                ),
              ),
              SizedBox(height: compact ? 16 : 28),
              Expanded(
            child: Container(
              width: double.infinity,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: IntroColors.mintCard,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Viewport into a taller thread: cut through the photo at the
                  // top and the last reply at the bottom (no vertical padding).
                  OverflowBox(
                    maxHeight: double.infinity,
                    alignment: const Alignment(0, -0.15),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(
                            alignment: Alignment.centerRight,
                            child: _enter(
                              index: 0,
                              child: const _UserOutfitBubble(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: _enter(
                              index: 1,
                              child: const _AiBubble(
                                text:
                                    'Looking great! What\'s the occasion for this outfit?',
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: _enter(
                              index: 2,
                              child: const _UserPillBubble(text: 'To the office'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: _enter(
                              index: 3,
                              child: const _AiBubble(
                                text:
                                    'This works for a casual office. The leather jacket and loafers are doing a lot of the heavy lifting. Try a slimmer trouser cut and you\'re there.',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 40,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              IntroColors.mintCard,
                              Color(0x00E5EEE3),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 44,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              IntroColors.mintCard,
                              Color(0x00E5EEE3),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
            ],
          );
        },
      ),
    );
  }
}

class _UserOutfitBubble extends StatelessWidget {
  const _UserOutfitBubble();

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 240),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(20),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Image.asset(
              'assets/imgs/intro/chat_outfit.png',
              height: 168,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Text(
                'What do you think about my outfit?',
                style: TextStyle(
                  fontFamily: 'Metropolis',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserPillBubble extends StatelessWidget {
  const _UserPillBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Metropolis',
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _AiBubble extends StatelessWidget {
  const _AiBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: math.min(280, MediaQuery.sizeOf(context).width * 0.72),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontFamily: 'Metropolis',
            fontSize: 13.5,
            fontWeight: FontWeight.w400,
            height: 1.4,
            color: Color(0xFF2A2F2A),
          ),
        ),
      ),
    );
  }
}
