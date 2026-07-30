import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:gostylens/core/config/dependency_injection.dart';
import 'package:gostylens/core/managers/style_analysis_session/index.dart';
import 'package:gostylens/core/managers/user_state_manager.dart';
import 'package:gostylens/models/api_responses/api_response.dart';
import 'package:gostylens/models/user_state.dart';
import 'package:gostylens/navigation/auth_flow_user_state.dart';

/// High-level stages the app can be in while resolving auth + profile state.
enum AuthStage { booting, unauthenticated, onboarding, userReady, error }

@visibleForTesting
AuthStage deriveAuthStage({
  required bool splashRevealCompleted,
  required bool authResolved,
  required bool hasSession,
  required bool hasUser,
  required UserFetchStatus fetchStatus,
}) {
  if (!splashRevealCompleted || !authResolved) return AuthStage.booting;
  if (!hasSession) return AuthStage.unauthenticated;

  // Once a profile is loaded, keep Home visible through background refreshes
  // (loading) and even refresh failures — never eject a logged-in user.
  if (hasUser &&
      (fetchStatus == UserFetchStatus.ready ||
          fetchStatus == UserFetchStatus.loading ||
          fetchStatus == UserFetchStatus.initial ||
          fetchStatus == UserFetchStatus.error)) {
    return AuthStage.userReady;
  }

  return switch (fetchStatus) {
    UserFetchStatus.onboarding => AuthStage.onboarding,
    UserFetchStatus.ready => AuthStage.userReady,
    UserFetchStatus.error => AuthStage.error,
    // First load still in flight (no cached user yet).
    UserFetchStatus.initial || UserFetchStatus.loading => AuthStage.booting,
  };
}

/// Owns the auth + profile + splash-reveal state machine and exposes the derived
/// [stage]. It is wired as the GoRouter `refreshListenable`; all navigation
/// (redirects, deep links) is driven declaratively off [stage] by the router
/// and `main`, so this controller performs no navigation itself.
class AuthFlowController extends ChangeNotifier {
  AuthFlowController({
    SupabaseClient? client,
    AuthFlowUserState? userState,
    Duration splashFallbackDuration = const Duration(milliseconds: 2500),
  })  : _client = client ?? locator<SupabaseClient>(),
        _userState = userState ?? locator<UserStateManager>(),
        _splashFallbackDuration = splashFallbackDuration;

  final SupabaseClient _client;
  final AuthFlowUserState _userState;
  final Duration _splashFallbackDuration;

  StreamSubscription<AuthState>? _authSubscription;
  Timer? _splashTimer;
  bool _disposed = false;

  bool _splashRevealCompleted = false;
  bool _authResolved = false;
  Session? _session;

  AuthStage _stage = AuthStage.booting;
  AuthStage get stage => _stage;

  ErrorData? get errorData => _userState.lastError;

  /// Begins listening to auth + profile state and starts the splash safety timer.
  void start() {
    _session = _client.auth.currentSession;
    _authSubscription = _client.auth.onAuthStateChange.listen(_onAuthEvent);
    _userState.addListener(_evaluate);
    _splashTimer = Timer(_splashFallbackDuration, markSplashRevealCompleted);
    _evaluate();
  }

  /// Called when the boot logo-reveal has played once (or failed to load).
  void markSplashRevealCompleted() {
    if (_disposed || _splashRevealCompleted) return;
    _splashRevealCompleted = true;
    _splashTimer?.cancel();
    _splashTimer = null;
    _evaluate();
  }

  /// Retries profile resolution after an error.
  void retry() {
    _userState.clearState();
  }

  void _onAuthEvent(AuthState data) {
    _authResolved = true;
    _session = data.session;
    final event = data.event;

    if (event == AuthChangeEvent.signedOut ||
        (event == AuthChangeEvent.initialSession && data.session == null)) {
      // Single owner of user/subscription cleanup on sign-out.
      _userState.clearState();
      locator<StyleAnalysisSessionManager>().clearMessageCache();
    }

    if (event == AuthChangeEvent.userUpdated) {
      _userState.fetchCurrentUser();
    }

    _evaluate();
  }

  void _evaluate() {
    if (_disposed) return;

    _maybeFetchProfile();

    final next = _computeStage();
    if (next == _stage) return;

    _stage = next;
    notifyListeners();
  }

  void _maybeFetchProfile() {
    if (_session == null) return;
    if (_userState.operationState.fetchStatus != UserFetchStatus.initial) return;

    Future.microtask(() {
      if (_disposed || _session == null) return;
      if (_userState.operationState.fetchStatus == UserFetchStatus.initial) {
        _userState.fetchCurrentUser();
      }
    });
  }

  AuthStage _computeStage() {
    return deriveAuthStage(
      splashRevealCompleted: _splashRevealCompleted,
      authResolved: _authResolved,
      hasSession: _session != null,
      hasUser: _userState.currentUser != null,
      fetchStatus: _userState.operationState.fetchStatus,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _authSubscription?.cancel();
    _splashTimer?.cancel();
    _userState.removeListener(_evaluate);
    super.dispose();
  }
}
