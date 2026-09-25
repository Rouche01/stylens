import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:gostylens/core/navigation/deep_link/deep_link_destination.dart';
import 'package:gostylens/widgets/floating_nav_bar.dart';

/// Frosted in-app notification chrome (variant G): body + dismiss, optional
/// stacked lime CTA. Used for all foreground push snackbars.
class InAppNotificationSnackBar extends StatelessWidget {
  const InAppNotificationSnackBar({
    super.key,
    required this.body,
    required this.onDismiss,
    this.actionLabel,
    this.onAction,
  });

  static const double radius = 26;
  static const double horizontalInset = 16;
  static const double dockGap = 14;

  /// Bottom margin that clears the floating nav dock with a visible gap.
  static EdgeInsets marginFor(BuildContext? context) {
    final bottom = context != null
        ? FloatingNavBar.contentBottomInset(context) + dockGap
        : FloatingNavBar.height + dockGap + horizontalInset;
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              color: Color.lerp(
                cs.primary,
                cs.secondary,
                0.08,
              )!.withValues(alpha: 0.88),
              border: Border.all(
                color: cs.secondary.withValues(alpha: 0.22),
                width: 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 6, _showAction ? 12 : 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(
                            top: 8,
                            bottom: 6,
                            right: 4,
                          ),
                          child: Text(
                            body,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.96),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: onDismiss,
                        tooltip: 'Dismiss',
                        visualDensity: VisualDensity.compact,
                        iconSize: 20,
                        color: Colors.white.withValues(alpha: 0.85),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  if (_showAction) ...[
                    const SizedBox(height: 2),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilledButton(
                          onPressed: onAction,
                          style: FilledButton.styleFrom(
                            backgroundColor: cs.secondary,
                            foregroundColor: cs.primary,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 9,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: const StadiumBorder(),
                          ),
                          child: Text(
                            actionLabel!,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
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
