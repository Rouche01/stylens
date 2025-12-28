// lib/widgets/fullscreen_loader.dart
import 'package:flutter/material.dart';

class FullScreenLoader extends StatelessWidget {
  final bool isLoading;
  final String? message;
  final Widget? customLoader;

  const FullScreenLoader({
    super.key,
    required this.isLoading,
    this.message,
    this.customLoader,
  });

  @override
  Widget build(BuildContext context) {
    if (!isLoading) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;

    return Positioned.fill(
      child: AnimatedOpacity(
        opacity: isLoading ? 1 : 0,
        duration: const Duration(milliseconds: 250),
        child: Container(
          color: colorScheme.surface.withValues(alpha: 0.9), // background tint
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                customLoader ??
                    CircularProgressIndicator(
                      color: colorScheme.primary,
                      strokeWidth: 3,
                    ),
                if (message != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    message!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
