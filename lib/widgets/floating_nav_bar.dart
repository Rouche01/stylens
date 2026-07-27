import 'dart:ui';

import 'package:flutter/material.dart';

/// Floating glass-style bottom navigation bar for Closet / Capture / History.
class FloatingNavBar extends StatelessWidget {
  const FloatingNavBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  /// Visual height of the bar (icon + label pill).
  static const double height = 64;

  /// How far to pull the dock into the system safe area (lower = closer to edge).
  static const double safeAreaNudge = 6;

  static const _radius = 26.0;

  /// Offset from the screen bottom to the dock's bottom edge.
  static double dockBottomInset(BuildContext context) {
    final systemBottom = MediaQuery.viewPaddingOf(context).bottom;
    return (systemBottom - safeAreaNudge).clamp(4.0, double.infinity);
  }

  /// Space to reserve so content clears the floating dock.
  static double contentBottomInset(BuildContext context) {
    return dockBottomInset(context) + height;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_radius),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_radius),
              // Green-tinted glass: translucent primary + soft lime rim light.
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.lerp(
                    cs.primary,
                    cs.secondary,
                    0.22,
                  )!.withValues(alpha: 0.55),
                  cs.primary.withValues(alpha: 0.62),
                ],
              ),
              border: Border.all(
                color: cs.secondary.withValues(alpha: 0.28),
                width: 0.5,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
              child: Row(
                children: [
                  Expanded(
                    child: _NavItem(
                      icon: Icons.checkroom_outlined,
                      selectedIcon: Icons.checkroom,
                      label: 'Closet',
                      selected: selectedIndex == 0,
                      onTap: () => onDestinationSelected(0),
                    ),
                  ),
                  Expanded(
                    child: _NavItem(
                      icon: Icons.camera_alt_outlined,
                      selectedIcon: Icons.camera_alt,
                      label: 'Capture',
                      selected: selectedIndex == 1,
                      onTap: () => onDestinationSelected(1),
                    ),
                  ),
                  Expanded(
                    child: _NavItem(
                      icon: Icons.history_outlined,
                      selectedIcon: Icons.history,
                      label: 'History',
                      selected: selectedIndex == 2,
                      onTap: () => onDestinationSelected(2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Lime pill + dark green ink reads clearly on the green glass shell.
    final foreground = selected
        ? cs.primary
        : Colors.white.withValues(alpha: 0.78);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? cs.secondary.withValues(alpha: 0.92)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? selectedIcon : icon, size: 21, color: foreground),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foreground,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                height: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
