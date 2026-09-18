import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Floating glass-style bottom navigation bar for Closet / Capture / History.
class FloatingNavBar extends StatefulWidget {
  const FloatingNavBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.closetProcessing = false,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  /// Lime pulse on the Closet hanger. Pass only when Closet is not selected.
  final bool closetProcessing;

  /// Visual height of the bar (icon + label pill).
  static const double height = 64;

  /// How far to pull the dock into the system safe area (lower = closer to edge).
  static const double safeAreaNudge = 6;

  /// Delay before the active-tab icon bounce so it lands with the sliding pill.
  static const Duration iconBounceDelay = Duration(milliseconds: 140);

  /// Duration of the sliding pill when switching tabs — keep shell fades in sync.
  static const Duration tabTransitionDuration = Duration(milliseconds: 320);
  static const Curve tabTransitionCurve = Curves.easeOutCubic;

  static const _radius = 26.0;
  static const _inset = 5.0;

  static const _destinations = <_NavDestination>[
    _NavDestination(
      icon: Icons.checkroom_outlined,
      selectedIcon: Icons.checkroom,
      label: 'Closet',
    ),
    _NavDestination(
      icon: Icons.camera_alt_outlined,
      selectedIcon: Icons.camera_alt,
      label: 'Capture',
    ),
    _NavDestination(
      icon: Icons.history_outlined,
      selectedIcon: Icons.history,
      label: 'History',
    ),
  ];

  static int get _itemCount => _destinations.length;

  /// Offset from the screen bottom to the dock's bottom edge.
  static double dockBottomInset(BuildContext context) {
    final systemBottom = MediaQuery.viewPaddingOf(context).bottom;
    return (systemBottom - safeAreaNudge).clamp(4.0, double.infinity);
  }

  /// Space to reserve so content clears the floating dock.
  static double contentBottomInset(BuildContext context) {
    return dockBottomInset(context) + height;
  }

  static bool reduceMotionOf(BuildContext context) {
    final media = MediaQuery.of(context);
    return media.disableAnimations || media.accessibleNavigation;
  }

  @override
  State<FloatingNavBar> createState() => _FloatingNavBarState();
}

class _FloatingNavBarState extends State<FloatingNavBar>
    with SingleTickerProviderStateMixin {
  static const _slideDuration = FloatingNavBar.tabTransitionDuration;

  late final AnimationController _slideController;
  late Animation<double> _indexAnimation;
  late int _fromIndex;

  @override
  void initState() {
    super.initState();
    _fromIndex = widget.selectedIndex;
    _slideController = AnimationController(
      vsync: this,
      duration: _slideDuration,
      value: 1,
    );
    _indexAnimation = AlwaysStoppedAnimation(widget.selectedIndex.toDouble());
  }

  @override
  void didUpdateWidget(FloatingNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex == widget.selectedIndex) return;

    HapticFeedback.selectionClick();

    final reduceMotion = FloatingNavBar.reduceMotionOf(context);
    _fromIndex = oldWidget.selectedIndex;

    if (reduceMotion) {
      _indexAnimation = AlwaysStoppedAnimation(widget.selectedIndex.toDouble());
      _slideController.value = 1;
      return;
    }

    _indexAnimation =
        Tween<double>(
          begin: _fromIndex.toDouble(),
          end: widget.selectedIndex.toDouble(),
        ).animate(
          CurvedAnimation(
            parent: _slideController,
            curve: FloatingNavBar.tabTransitionCurve,
          ),
        );
    _slideController.forward(from: 0);
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  Alignment _alignmentForIndex(double index) {
    // Map 0..2 → Alignment.x -1..1 for equal-width tabs.
    final t = index / (FloatingNavBar._itemCount - 1);
    return Alignment(-1 + 2 * t, 0);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final selectedIndex = widget.selectedIndex;
    final reduceMotion = FloatingNavBar.reduceMotionOf(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(FloatingNavBar._radius),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(FloatingNavBar._radius),
        child: BackdropFilter(
          // Stronger frost so a lighter fill still keeps icons readable.
          filter: ImageFilter.blur(sigmaX: 36, sigmaY: 36),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(FloatingNavBar._radius),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.lerp(
                    cs.primary,
                    cs.secondary,
                    0.18,
                  )!.withValues(alpha: 0.46),
                  cs.primary.withValues(alpha: 0.55),
                ],
              ),
              border: Border.all(
                color: cs.secondary.withValues(alpha: 0.32),
                width: 0.5,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(FloatingNavBar._inset),
              child: SizedBox(
                height: FloatingNavBar.height - FloatingNavBar._inset * 2,
                child: AnimatedBuilder(
                  animation: _slideController,
                  builder: (context, _) {
                    final indexValue = _indexAnimation.value;
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        Align(
                          alignment: _alignmentForIndex(indexValue),
                          child: FractionallySizedBox(
                            widthFactor: 1 / FloatingNavBar._itemCount,
                            heightFactor: 1,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 2,
                              ),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: cs.secondary.withValues(alpha: 0.92),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            for (
                              var i = 0;
                              i < FloatingNavBar._destinations.length;
                              i++
                            )
                              Expanded(
                                child: _NavItem(
                                  destination: FloatingNavBar._destinations[i],
                                  selected: selectedIndex == i,
                                  reduceMotion: reduceMotion,
                                  showProcessingDot:
                                      widget.closetProcessing &&
                                      i == 0 &&
                                      selectedIndex != 0,
                                  onTap: () => widget.onDestinationSelected(i),
                                ),
                              ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavDestination {
  const _NavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.reduceMotion,
    required this.showProcessingDot,
    required this.onTap,
  });

  final _NavDestination destination;
  final bool selected;
  final bool reduceMotion;
  final bool showProcessingDot;
  final VoidCallback onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounceController;
  late final Animation<double> _bounceScale;
  Timer? _bounceDelay;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _bounceScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 1.12,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.12,
          end: 0.96,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 0.96,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
    ]).animate(_bounceController);

    if (widget.selected) {
      _bounceController.value = 1;
    }
  }

  @override
  void didUpdateWidget(_NavItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.selected && widget.selected) {
      _bounceDelay?.cancel();
      if (widget.reduceMotion) {
        _bounceController.value = 1;
        return;
      }
      _bounceDelay = Timer(FloatingNavBar.iconBounceDelay, () {
        if (!mounted || !widget.selected) return;
        _bounceController.forward(from: 0);
      });
    } else if (oldWidget.selected && !widget.selected) {
      _bounceDelay?.cancel();
      _bounceController.value = 0;
    }
  }

  @override
  void dispose() {
    _bounceDelay?.cancel();
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final activeColor = cs.primary;
    final inactiveColor = Color.lerp(
      cs.secondary,
      Colors.white,
      0.78,
    )!.withValues(alpha: 0.88);
    final colorDuration = widget.reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 220);
    final destination = widget.destination;

    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.showProcessingDot
          ? '${destination.label}, hanging pieces'
          : destination.label,
      onTap: widget.onTap,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: _bounceScale,
                  child: TweenAnimationBuilder<Color?>(
                    duration: colorDuration,
                    curve: Curves.easeOut,
                    tween: ColorTween(
                      end: widget.selected ? activeColor : inactiveColor,
                    ),
                    builder: (context, color, _) {
                      final icon = AnimatedSwitcher(
                        duration: colorDuration,
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        child: Icon(
                          widget.selected
                              ? destination.selectedIcon
                              : destination.icon,
                          key: ValueKey<bool>(widget.selected),
                          size: 21,
                          color: color ?? inactiveColor,
                        ),
                      );
                      if (!widget.showProcessingDot) return icon;
                      return SizedBox(
                        width: 21,
                        height: 21,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Center(child: icon),
                            const Positioned(
                              top: -5,
                              right: -5,
                              child: IgnorePointer(child: _HangerPulseDot()),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 3),
                AnimatedDefaultTextStyle(
                  duration: colorDuration,
                  style: TextStyle(
                    color: widget.selected ? activeColor : inactiveColor,
                    fontSize: 11,
                    fontWeight: widget.selected
                        ? FontWeight.w600
                        : FontWeight.w500,
                    height: 1.0,
                  ),
                  child: Text(
                    destination.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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

class _HangerPulseDot extends StatefulWidget {
  const _HangerPulseDot();

  static const double canvas = 18;

  @override
  State<_HangerPulseDot> createState() => _HangerPulseDotState();
}

class _HangerPulseDotState extends State<_HangerPulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  void _sync() {
    if (FloatingNavBar.reduceMotionOf(context)) {
      _pulse.stop();
      _pulse.value = 0;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final reduceMotion = FloatingNavBar.reduceMotionOf(context);

    return SizedBox(
      key: const ValueKey('closet-hanger-pulse'),
      width: _HangerPulseDot.canvas,
      height: _HangerPulseDot.canvas,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) {
          return CustomPaint(
            painter: _HangerPulsePainter(
              progress: _pulse.value,
              lime: cs.secondary,
              halo: cs.primary,
              reduceMotion: reduceMotion,
            ),
          );
        },
      ),
    );
  }
}

class _HangerPulsePainter extends CustomPainter {
  const _HangerPulsePainter({
    required this.progress,
    required this.lime,
    required this.halo,
    required this.reduceMotion,
  });

  final double progress;
  final Color lime;
  final Color halo;
  final bool reduceMotion;

  static const _coreRadius = 3.5;
  static const _haloWidth = 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    if (!reduceMotion) {
      final t = Curves.easeOut.transform(progress);
      canvas.drawCircle(
        center,
        _coreRadius + 1 + 5 * t,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.25
          ..color = lime.withValues(alpha: 0.7 * (1 - t)),
      );
    }

    canvas.drawCircle(center, _coreRadius + _haloWidth, Paint()..color = halo);
    canvas.drawCircle(center, _coreRadius, Paint()..color = lime);
  }

  @override
  bool shouldRepaint(covariant _HangerPulsePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.lime != lime ||
        oldDelegate.halo != halo ||
        oldDelegate.reduceMotion != reduceMotion;
  }
}
