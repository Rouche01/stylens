import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:gostylens/core/config/dependency_injection.dart';
import 'package:lottie/lottie.dart';
import 'global_loader_controller.dart';

class GlobalLoaderScope extends StatelessWidget {
  final Widget child;
  const GlobalLoaderScope({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final controller = locator<GlobalLoaderController>();

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
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        color: cs.tertiary.withValues(
                          alpha: 0.8,
                        ), // slightly transparent tint
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Lottie.asset(
                                'assets/animations/logo-loader.json',
                                height: 30,
                                errorBuilder: (context, error, stackTrace) {
                                  // Fallback if the user hasn't added the 'assets/loader.json' file yet
                                  debugPrint('LOTTIE ERROR: $error');
                                  return CircularProgressIndicator(
                                    color: cs.primary,
                                    strokeWidth: 3,
                                  );
                                },
                              ),
                              if (controller.message != null) ...[
                                const SizedBox(height: 16),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24.0,
                                  ),
                                  child: Text(
                                    controller.message!,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: cs.onSurface,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w400,
                                      decoration: TextDecoration.none,
                                      fontFamily: 'Metropolis',
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
                ),
              ),
          ],
        );
      },
    );
  }
}
