import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gostylens/core/managers/user_state_manager.dart';
import 'package:gostylens/pages/auth.dart';
import 'package:gostylens/pages/home.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final StreamSubscription<AuthState> _authStateSubscription;

  @override
  void initState() {
    super.initState();

    // Listen for auth changes
    _authStateSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;

      if (!mounted) return;

      if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.initialSession) {
        if (session != null) {
          // Fetch the user data locally before letting them in
          context.read<UserStateManager>().fetchCurrentUser(
            onSuccess: (user) {
              if (mounted) {
                debugPrint("User fetched successfully ${user.toJson()}");

                FlutterNativeSplash.remove();
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => MyHomePage()),
                );
              }
            },
            onError: (error) {
              // If fetching user profile fails, perhaps they need onboarding or it's a network issue.
              // For safety, log them out or direct them to AuthPage so they can re-initiate
              Supabase.instance.client.auth.signOut();
            },
          );
        } else {
          FlutterNativeSplash.remove();
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const AuthPage()),
          );
        }
      } else if (event == AuthChangeEvent.signedOut) {
        FlutterNativeSplash.remove();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const AuthPage()),
        );
      }
    });
  }

  @override
  void dispose() {
    _authStateSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The native splash screen will continue showing over this blank scaffold
    // until we explicitly call FlutterNativeSplash.remove() during routing.
    return Scaffold(backgroundColor: Theme.of(context).colorScheme.primary);
  }
}
