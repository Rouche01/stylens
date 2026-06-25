import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:gostylens/core/config/dependency_injection.dart';
import 'package:gostylens/core/managers/user_state_manager.dart';
import 'package:gostylens/core/navigation/app_navigation_keys.dart';
import 'package:gostylens/core/navigation/deep_link/deep_link_service.dart';
import 'package:gostylens/core/navigation/home_tab_controller.dart';
import 'package:gostylens/models/api_responses/api_response.dart';
import 'package:gostylens/models/user_state.dart';
import 'package:gostylens/navigation/auth_flow_user_state.dart';

/// High-level stages the app can be in while resolving auth + profile state.
enum AuthStage { booting, unauthenticated, onboarding, userReady, error }

@visibleForTesting
AuthStage deriveAuthStage({
  required bool minSplashDurationElapsed,
  required bool authResolved,
  required bool hasSession,
  required bool hasUser,
  required UserFetchStatus fetchStatus,
}) {
  if (!minSplashDurationElapsed || !authResolved) return AuthStage.booting;
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

/// Owns the auth + profile + splash state machine and performs all side effects
/// (splash removal, deep-link readiness, tab reset, route stack cleanup) on
/// stage transitions. [AuthGate] is a thin view that simply renders [stage].
class AuthFlowController extends ChangeNotifier {
  AuthFlowController({
    SupabaseClient? client,
    AuthFlowUserState? userState,
    DeepLinkService? deepLinkService,
    HomeTabController? homeTabController,
    GlobalKey<NavigatorState>? navigatorKey,
    Duration minSplashDuration = const Duration(milliseconds: 1200),
  })  : _client = client ?? locator<SupabaseClient>(),
        _userState = userState ?? locator<UserStateManager>(),
        _deepLink = deepLinkService ?? locator<DeepLinkService>(),
        _homeTab = homeTabController ?? locator<HomeTabController>(),
        _navigatorKey = navigatorKey ?? rootNavigatorKey,
        _minSplashDuration = minSplashDuration;

  final SupabaseClient _client;
  final AuthFlowUserState _userState;
  final DeepLinkService _deepLink;
  final HomeTabController _homeTab;
  final GlobalKey<NavigatorState> _navigatorKey;
  final Duration _minSplashDuration;

  StreamSubscription<AuthState>? _authSubscription;
  Timer? _splashTimer;
  bool _disposed = false;

  bool _minSplashDurationElapsed = false;
  bool _authResolved = false;
  bool _splashRemoved = false;
  Session? _session;

  AuthStage _stage = AuthStage.booting;
  AuthStage get stage => _stage;

  ErrorData? get errorData => _userState.lastError;

  /// Begins listening to auth + profile state and starts the min-splash timer.
  void start() {
    _session = _client.auth.currentSession;
    _authSubscription = _client.auth.onAuthStateChange.listen(_onAuthEvent);
    _userState.addListener(_evaluate);
    _splashTimer = Timer(_minSplashDuration, () {
      _minSplashDurationElapsed = true;
      _evaluate();
    });
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

    final previous = _stage;
    _stage = next;
    notifyListeners();
    _runTransitionEffects(previous, next);
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
      minSplashDurationElapsed: _minSplashDurationElapsed,
      authResolved: _authResolved,
      hasSession: _session != null,
      hasUser: _userState.currentUser != null,
      fetchStatus: _userState.operationState.fetchStatus,
    );
  }

  void _runTransitionEffects(AuthStage previous, AuthStage next) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (_disposed) return;

      if (!_splashRemoved && next != AuthStage.booting) {
        _splashRemoved = true;
        FlutterNativeSplash.remove();
      }

      final hadPendingDeepLink = _deepLink.hasPending;

      // Clear any pushed routes FIRST, so a deep link consumed below lands on a
      // clean stack and is not immediately popped on the same frame.
      if (_shouldClearStack(previous, next)) {
        _navigatorKey.currentState?.popUntil((route) => route.isFirst);
      }

      // Reset to Capture only on a genuine fresh entry to Home with no pending
      // deep link; otherwise let the deep link decide the destination.
      final enteringUserReadyFromAuthFlow = next == AuthStage.userReady &&
          (previous == AuthStage.unauthenticated ||
              previous == AuthStage.onboarding);
      if (enteringUserReadyFromAuthFlow && !hadPendingDeepLink) {
        _homeTab.setTab(HomeTabController.captureIndex);
      }

      // Mark navigation ready last; this flushes any pending deep link, pushing
      // it on top of the now-cleaned stack.
      _deepLink.setNavigationReady(next == AuthStage.userReady);
    });
  }

  /// Clears any pushed routes on real auth/onboarding/error transitions, but NOT
  /// when reaching userReady from booting — that would dismiss deep-linked routes
  /// (paywall/billing/session) pushed during cold start.
  bool _shouldClearStack(AuthStage previous, AuthStage next) {
    return switch (next) {
      AuthStage.unauthenticated ||
      AuthStage.onboarding ||
      AuthStage.error =>
        true,
      AuthStage.userReady =>
        previous == AuthStage.unauthenticated ||
            previous == AuthStage.onboarding,
      AuthStage.booting => false,
    };
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
