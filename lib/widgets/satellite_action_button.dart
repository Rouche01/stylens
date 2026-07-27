import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Accent satellite action meant to sit above [FloatingNavBar].
///
/// Uses a solid lime fill (not matching glass chrome) so it reads as the
/// primary create CTA next to the floating dock.
class SatelliteActionButton extends StatefulWidget {
  const SatelliteActionButton({
    super.key,
    required this.onPressed,
    this.icon = Icons.auto_awesome,
    this.tooltip = 'New session',
  });

  final VoidCallback onPressed;
  final IconData icon;
  final String tooltip;

  static const double size = 60;

  /// Tight gap between the satellite and the top of the floating dock.
  static const double gapAboveDock = 12;

  /// Horizontal inset — match [FloatingNavBar] side padding in [HomeShell].
  static const double sideInset = 16;

  @override
  State<SatelliteActionButton> createState() => _SatelliteActionButtonState();
}

class _SatelliteActionButtonState extends State<SatelliteActionButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  void _handleTap() {
    HapticFeedback.lightImpact();
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      label: widget.tooltip,
      tooltip: widget.tooltip,
      onTap: _handleTap,
      child: Tooltip(
        message: widget.tooltip,
        preferBelow: false,
        waitDuration: const Duration(milliseconds: 400),
        child: GestureDetector(
          onTapDown: (_) => _setPressed(true),
          onTapUp: (_) => _setPressed(false),
          onTapCancel: () => _setPressed(false),
          onTap: _handleTap,
          child: ExcludeSemantics(
            child: AnimatedScale(
              scale: _pressed ? 0.92 : 1.0,
              duration: const Duration(milliseconds: 100),
              curve: Curves.easeOut,
              child: Material(
                color: cs.secondary,
                shape: const CircleBorder(),
                elevation: _pressed ? 3 : 6,
                shadowColor: cs.primary.withValues(alpha: 0.45),
                child: SizedBox(
                  width: SatelliteActionButton.size,
                  height: SatelliteActionButton.size,
                  child: Icon(
                    widget.icon,
                    size: 30,
                    color: cs.primary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
