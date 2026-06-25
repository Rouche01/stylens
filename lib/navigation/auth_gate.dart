import 'package:flutter/material.dart';
import 'package:gostylens/navigation/auth_flow_controller.dart';
import 'package:gostylens/pages/auth.dart';
import 'package:gostylens/pages/home.dart';
import 'package:gostylens/pages/onboarding_name.dart';
import 'package:gostylens/widgets/auth_error_view.dart';
import 'package:gostylens/widgets/auth_loading_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final AuthFlowController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AuthFlowController()..start();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final child = switch (_controller.stage) {
          AuthStage.booting => const AuthLoadingScreen(key: ValueKey('loading')),
          AuthStage.unauthenticated =>
            const AuthPage(key: ValueKey('auth_page')),
          AuthStage.onboarding =>
            const OnboardingNamePage(key: ValueKey('onboarding_page')),
          AuthStage.userReady => MyHomePage(key: const ValueKey('home_page')),
          AuthStage.error => AuthErrorView(
              key: const ValueKey('error_page'),
              error: _controller.errorData,
              onRetry: _controller.retry,
            ),
        };

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 600),
          switchInCurve: Curves.easeInOut,
          switchOutCurve: Curves.easeInOut,
          child: child,
        );
      },
    );
  }
}
