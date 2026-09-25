import 'package:flutter/material.dart';
import 'package:gostylens/core/navigation/deep_link/deep_link_destination.dart';
import 'package:gostylens/widgets/floating_nav_bar.dart';

/// Neutral charcoal in-app notification chrome (refine preview **B**):
/// inline body + compact CTA + dismiss, pop shadow, tight dock gap.
class InAppNotificationSnackBar extends StatelessWidget {
  const InAppNotificationSnackBar({
    super.key,
    required this.body,
    required this.onDismiss,
    this.actionLabel,
    this.onAction,
  });

  static const double radius = 18;
  static const double horizontalInset = 16;

  /// Air between snackbar bottom and floating dock top (preview B default).
  static const double dockGap = 4;

  /// Fallback bottom pad when the floating dock is not on screen.
  static const double _noDockBottom = 12;

  /// Neutral slate charcoal — lighter than near-black, still distinct from olive.
  static const Color _fill = Color(0xF22E3238);

  /// Bottom margin for a floating [SnackBar].
  ///
  /// When [clearFloatingDock] is true (main tab shell), clears the floating
  /// nav with [dockGap] of air. Scaffold already lifts floating snackbars above
  /// [MediaQuery.viewPadding] bottom — that inset must not be counted twice.
  ///
  /// When false (session / paywall / profile / auth), only a small bottom pad
  /// so we don't reserve phantom dock space where the bar isn't visible.
  static EdgeInsets marginFor(
    BuildContext? context, {
    bool clearFloatingDock = true,
  }) {
    if (!clearFloatingDock) {
      return const EdgeInsets.fromLTRB(
        horizontalInset,
        0,
        horizontalInset,
        _noDockBottom,
      );
    }

    if (context == null) {
      return EdgeInsets.fromLTRB(
        horizontalInset,
        0,
        horizontalInset,
        FloatingNavBar.height + dockGap,
      );
    }

    final viewBottom = MediaQuery.viewPaddingOf(context).bottom;
    final dockTop = FloatingNavBar.contentBottomInset(context);
    final bottom = (dockTop + dockGap - viewBottom).clamp(
      dockGap,
      double.infinity,
    );

    return EdgeInsets.fromLTRB(horizontalInset, 0, horizontalInset, bottom);
  }

  final String body;
  final VoidCallback onDismiss;
  final String? actionLabel;
  final VoidCallback? onAction;

  bool get _showAction =>
      actionLabel != null && actionLabel!.isNotEmpty && onAction != null;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      type: MaterialType.transparency,
      // Shadow lives outside the clip so it isn't cut off.
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.42),
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _fill,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
                width: 0.5,
              ),
            ),
            // Slightly roomier than preview B so body/CTA aren't cramped.
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      body,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.96),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                  ),
                  if (_showAction) ...[
                    const SizedBox(width: 4),
                    TextButton(
                      onPressed: onAction,
                      style: TextButton.styleFrom(
                        foregroundColor: cs.secondary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                      child: Text(
                        actionLabel!,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: IconButton(
                      onPressed: onDismiss,
                      tooltip: 'Dismiss',
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      iconSize: 18,
                      color: Colors.white.withValues(alpha: 0.85),
                      icon: const Icon(Icons.close),
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

/// Short pill label for a deep-link destination (in-app snackbar CTA).
String actionLabelForDestination(DeepLinkDestination destination) {
  return switch (destination.target) {
    DeepLinkTarget.capture => 'Capture',
    DeepLinkTarget.closet => 'Closet',
    DeepLinkTarget.history => 'History',
    DeepLinkTarget.session ||
    DeepLinkTarget.paywall ||
    DeepLinkTarget.billing => 'View',
  };
}
