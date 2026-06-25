import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Branded full-screen loader shown while auth bootstrap completes.
class AuthLoadingScreen extends StatelessWidget {
  const AuthLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('loading'),
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: Center(
        child: Lottie.asset(
          'assets/animations/gostylens-logo-reveal-v2.json',
          width: 300,
          height: 300,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
