import 'dart:ui';

import 'package:flutter/material.dart';
import 'global_loader_controller.dart';

class GlobalLoaderScope extends StatelessWidget {
  final Widget child;
  const GlobalLoaderScope({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final controller = GlobalLoaderController.instance;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final cs = Theme.of(context).colorScheme;

        return Stack(
          children: [
            child,
            if (controller.isLoading)
              Positioned.fill(
                child: IgnorePointer(
                  // blocks taps (incl. bottom nav)
                  ignoring: false,
                  child: AnimatedOpacity(
                    opacity: controller.isLoading ? 1 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                      child: Container(
                        color: cs.surface.withValues(
                          alpha: 0.7,
                        ), // slightly transparent tint
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(
                                color: cs.primary,
                                strokeWidth: 3,
                              ),
                              if (controller.message != null) ...[
                                const SizedBox(height: 16),
                                Text(
                                  controller.message!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: cs.onSurface,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    fontFamily: 'ClashDisplay',
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
