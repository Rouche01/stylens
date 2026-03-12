import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gostylens/core/managers/user_state_manager.dart';
import 'package:gostylens/pages/auth.dart';
import 'package:gostylens/pages/home.dart';
import 'package:gostylens/pages/onboarding_name.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
    // Listen for auth changes to clear the navigation stack
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) {
      final event = data.event;
      if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.signedOut ||
          event == AuthChangeEvent.userDeleted ||
          event == AuthChangeEvent.passwordRecovery ||
          event == AuthChangeEvent.initialSession) {
        if (mounted) {
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
      stream: Supabase.instance.client.auth.onAuthStateChange,
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
            if (!userState.hasCheckedProfile && !userState.isLoading) {
              Future.microtask(() => userState.fetchCurrentUser());
            }

            // Still loading profile? Show splash/loading
            if (!userState.hasCheckedProfile || userState.isLoading) {
              return Scaffold(
                backgroundColor: Theme.of(context).colorScheme.primary,
                body: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              );
            }

            Widget rootWidget;

            // Profile checked, needs onboarding?
            if (userState.needsOnboarding) {
              rootWidget = const OnboardingNamePage();
            }
            // Profile checked, exists?
            else if (userState.currentUser != null) {
              rootWidget = MyHomePage();
            }
            // Fallback: This means fetch failed for a non-onboarding reason (e.g. Server down)
            else {
              rootWidget = Scaffold(
                backgroundColor: Theme.of(context).colorScheme.surfaceDim,
                body: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Oops! Something went wrong',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        userState.lastError ??
                            'We were unable to load your profile. Please check your connection and try again.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => userState.resetState(),
                          child: const Text('Retry'),
                        ),
                      ),
                      TextButton(
                        onPressed:
                            () => Supabase.instance.client.auth.signOut(),
                        child: const Text('Back to Login'),
                      ),
                    ],
                  ),
                ),
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
