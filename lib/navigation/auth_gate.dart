import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gostylens/core/managers/user_state_manager.dart';
import 'package:gostylens/models/user_state.dart';
import 'package:gostylens/pages/auth.dart';
import 'package:gostylens/pages/home.dart';
import 'package:gostylens/pages/onboarding_name.dart';
import 'package:gostylens/widgets/auth_error_view.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gostylens/core/config/dependency_injection.dart';
import 'package:gostylens/core/navigation/deep_link/deep_link_service.dart';
import 'package:gostylens/core/navigation/home_tab_controller.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:lottie/lottie.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<AuthState>? _authSubscription;
  Type? _lastBuiltType;
  bool _showAnimationDelay = true;
  bool _wasNavigationReady = false;

  void _scheduleNavigationReadyUpdate(bool ready) {
    if (_wasNavigationReady == ready) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _wasNavigationReady == ready) return;
      _wasNavigationReady = ready;
      locator<DeepLinkService>().setNavigationReady(ready);
    });
  }

  void _handleStackCleanup(Type currentType) {
    if (_lastBuiltType != null && _lastBuiltType != currentType) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      });
    }
    _lastBuiltType = currentType;
  }

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() {
          _showAnimationDelay = false;
        });
      }
    });
    _authSubscription = locator<SupabaseClient>().auth.onAuthStateChange.listen((
      data,
    ) {
      final event = data.event;
      if (event == AuthChangeEvent.signedIn) {
        final deepLinkService = locator<DeepLinkService>();
        if (!deepLinkService.hasPending) {
          locator<HomeTabController>().setTab(HomeTabController.captureIndex);
        }
      }

      if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.signedOut ||
          event == AuthChangeEvent.userDeleted ||
          event == AuthChangeEvent.passwordRecovery ||
          event == AuthChangeEvent.initialSession) {
        if (mounted) {
          // Reset state on sign out, deletion, or if we start with no session
          if (event == AuthChangeEvent.signedOut ||
              event == AuthChangeEvent.userDeleted ||
              (event == AuthChangeEvent.initialSession &&
                  data.session == null)) {
            context.read<UserStateManager>().resetState();
          }

          // Pop everything back to the AuthGate root
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      }

      // If user metadata was updated (e.g. email change), force a refresh of our profile
      if (event == AuthChangeEvent.userUpdated) {
        if (mounted) {
          context.read<UserStateManager>().fetchCurrentUser();
        }
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userState = context.watch<UserStateManager>();
    return StreamBuilder<AuthState>(
      stream: locator<SupabaseClient>().auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session =
            snapshot.data?.session ??
            locator<SupabaseClient>().auth.currentSession;

        _scheduleNavigationReadyUpdate(
          session != null &&
              userState.operationState.fetchStatus == UserFetchStatus.ready,
        );

        Widget child;

        // If we are still waiting for the minimum animation display delay, show the Lottie loader
        if (_showAnimationDelay) {
          FlutterNativeSplash.remove();
          child = Scaffold(
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
        // 1. Unauthenticated -> Show Auth Page
        else if (session == null) {
          FlutterNativeSplash.remove();
          final widget = const AuthPage(key: ValueKey('auth_page'));
          _handleStackCleanup(widget.runtimeType);
          child = widget;
        }
        // 2. Authenticated -> Check Profile State
        else {
          // Profile not checked yet? Trigger fetch.
          if (userState.operationState.fetchStatus == UserFetchStatus.initial) {
            Future.microtask(() => userState.fetchCurrentUser());
          }

          // Still loading profile? Keep showing Lottie loader.
          if (userState.operationState.fetchStatus == UserFetchStatus.initial ||
              userState.operationState.fetchStatus == UserFetchStatus.loading) {
            child = Scaffold(
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
          } else {
            Widget rootWidget;

            // Profile checked, needs onboarding?
            if (userState.operationState.fetchStatus ==
                UserFetchStatus.onboarding) {
              rootWidget = const OnboardingNamePage(
                key: ValueKey('onboarding_page'),
              );
            }
            // Profile checked, exists?
            else if (userState.operationState.fetchStatus ==
                UserFetchStatus.ready) {
              rootWidget = MyHomePage(key: const ValueKey('home_page'));
            }
            // Fallback: This means fetch failed for a non-onboarding reason (e.g. Server down)
            else {
              rootWidget = AuthErrorView(
                key: const ValueKey('error_page'),
                error: userState.lastError,
                onRetry: () => userState.resetState(),
              );
            }

            FlutterNativeSplash.remove();
            _handleStackCleanup(rootWidget.runtimeType);
            child = rootWidget;
          }
        }

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
