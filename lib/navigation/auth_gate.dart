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
import 'package:flutter_native_splash/flutter_native_splash.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<AuthState>? _authSubscription;
  Type? _lastBuiltType;

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
    _authSubscription = locator<SupabaseClient>().auth.onAuthStateChange.listen((
      data,
    ) {
      final event = data.event;
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
    return StreamBuilder<AuthState>(
      stream: locator<SupabaseClient>().auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.data?.session;

        // 1. Unauthenticated -> Show Auth Page
        if (session == null) {
          FlutterNativeSplash.remove();
          final widget = const AuthPage();
          _handleStackCleanup(widget.runtimeType);
          return widget;
        }

        // 2. Authenticated -> Check Profile State
        return Consumer<UserStateManager>(
          builder: (context, userState, _) {
            // Profile not checked yet? Trigger fetch.
            if (userState.operationState.fetchStatus ==
                UserFetchStatus.initial) {
              Future.microtask(() => userState.fetchCurrentUser());
            }

            // Still loading profile? Keep showing splash (by returning a matching background)
            if (userState.operationState.fetchStatus ==
                    UserFetchStatus.initial ||
                userState.operationState.fetchStatus ==
                    UserFetchStatus.loading) {
              return Scaffold(
                backgroundColor: Theme.of(context).colorScheme.primary,
              );
            }

            Widget rootWidget;

            // Profile checked, needs onboarding?
            if (userState.operationState.fetchStatus ==
                UserFetchStatus.onboarding) {
              rootWidget = const OnboardingNamePage();
            }
            // Profile checked, exists?
            else if (userState.operationState.fetchStatus ==
                UserFetchStatus.ready) {
              rootWidget = MyHomePage();
            }
            // Fallback: This means fetch failed for a non-onboarding reason (e.g. Server down)
            else {
              rootWidget = AuthErrorView(
                error: userState.lastError,
                onRetry: () => userState.resetState(),
              );
            }

            FlutterNativeSplash.remove();
            _handleStackCleanup(rootWidget.runtimeType);
            return rootWidget;
          },
        );
      },
    );
  }
}
