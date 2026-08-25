import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import 'dart:async';

import 'package:gostylens/core/config/dependency_injection.dart';
import 'package:gostylens/core/managers/invite_code_store.dart';
import 'package:gostylens/core/managers/intro_walkthrough_store.dart';
import 'package:gostylens/core/managers/style_analysis_session/index.dart';
import 'package:gostylens/core/navigation/app_navigation_keys.dart';
import 'package:gostylens/core/navigation/deep_link/deep_link_destination.dart';
import 'package:gostylens/core/navigation/deep_link/deep_link_parser.dart';
import 'package:gostylens/core/navigation/deep_link/deep_link_service.dart';
import 'package:gostylens/core/services/analytics_service.dart';
import 'package:gostylens/navigation/app_routes.dart';
import 'package:gostylens/navigation/auth_flow_controller.dart';
import 'package:gostylens/pages/auth.dart';
import 'package:gostylens/pages/billing_plan.dart';
import 'package:gostylens/pages/closet.dart';
import 'package:gostylens/pages/capture.dart';
import 'package:gostylens/pages/history.dart';
import 'package:gostylens/pages/home.dart';
import 'package:gostylens/pages/intro/intro_walkthrough_page.dart';
import 'package:gostylens/pages/onboarding_gender.dart';
import 'package:gostylens/pages/onboarding_name.dart';
import 'package:gostylens/pages/otp_verification.dart';
import 'package:gostylens/pages/paywall.dart';
import 'package:gostylens/pages/profile_menu.dart';
import 'package:gostylens/pages/style_analysis.dart';
import 'package:gostylens/widgets/auth_error_view.dart';
import 'package:gostylens/widgets/auth_loading_screen.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

/// App-wide router instance. Assigned once in `main` after the
/// [AuthFlowController] is started, so out-of-tree callers (deep links, push
/// notifications) can navigate via [appRouter].
late final GoRouter appRouter;

final _shellNavigatorClosetKey = GlobalKey<NavigatorState>(
  debugLabel: 'shellCloset',
);
final _shellNavigatorCaptureKey = GlobalKey<NavigatorState>(
  debugLabel: 'shellCapture',
);
final _shellNavigatorHistoryKey = GlobalKey<NavigatorState>(
  debugLabel: 'shellHistory',
);

/// Builds the declarative route table. Auth gating is handled by [redirect]
/// driven by [auth] (also wired as `refreshListenable`).
GoRouter createAppRouter(
  AuthFlowController auth, {
  LottieComposition? splashComposition,
}) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: kDebugMode,
    refreshListenable: auth,
    observers: AnalyticsService.isEnabled
        ? <NavigatorObserver>[PosthogObserver()]
        : const <NavigatorObserver>[],
    redirect: (context, state) => _redirect(auth, state),
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => AuthLoadingScreen(
          composition: splashComposition,
          onRevealCompleted: auth.markSplashRevealCompleted,
        ),
      ),
      GoRoute(
        path: AppRoutes.intro,
        builder: (context, state) => const IntroWalkthroughPage(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const AuthPage(),
        routes: [
          GoRoute(
            path: 'otp',
            builder: (context, state) => OtpVerificationPage(
              email: state.uri.queryParameters['email'] ?? '',
            ),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.onboardingName,
        builder: (context, state) => const OnboardingNamePage(),
      ),
      GoRoute(
        path: AppRoutes.onboardingGender,
        builder: (context, state) => const OnboardingGenderPage(),
      ),
      GoRoute(
        path: AppRoutes.error,
        builder: (context, state) => AuthErrorView(
          error: auth.errorData,
          onRetry: auth.retry,
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            HomeShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            navigatorKey: _shellNavigatorClosetKey,
            routes: [
              GoRoute(
                path: AppRoutes.closet,
                builder: (context, state) => const ClosetPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellNavigatorCaptureKey,
            routes: [
              GoRoute(
                path: AppRoutes.capture,
                builder: (context, state) => const CapturePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellNavigatorHistoryKey,
            routes: [
              GoRoute(
                path: AppRoutes.history,
                builder: (context, state) => const HistoryPage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.sessionPattern,
        pageBuilder: (context, state) {
          final id = state.pathParameters['id'];
          if (id != null && id.isNotEmpty) {
            locator<StyleAnalysisSessionManager>().setSelectedSessionId(id);
          }
          // Stable key so `/session` → `/session/:id` replace keeps chat State.
          return NoTransitionPage<void>(
            key: const ValueKey('style_analysis_session'),
            child: StyleAnalysisPage(routeSessionId: id),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.sessionNew,
        pageBuilder: (context, state) => const NoTransitionPage<void>(
          key: ValueKey('style_analysis_session'),
          child: StyleAnalysisPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.paywall,
        builder: (context, state) => const PaywallPage(),
      ),
      GoRoute(
        path: AppRoutes.billing,
        builder: (context, state) => BillingPlanPage(),
      ),
      GoRoute(
        path: AppRoutes.profile,
        builder: (context, state) => const ProfileMenuPage(),
      ),
    ],
  );
}

/// Pure stage-to-location gating. Exposed for testing.
@visibleForTesting
String? redirectForStage(AuthStage stage, String location) {
  switch (stage) {
    case AuthStage.booting:
      return location == AppRoutes.splash ? null : AppRoutes.splash;
    case AuthStage.unauthenticated:
      if (location.startsWith(AppRoutes.login) ||
          location == AppRoutes.intro) {
        return null;
      }
      return AppRoutes.login;
    case AuthStage.onboarding:
      return location.startsWith(AppRoutes.onboarding)
          ? null
          : AppRoutes.onboardingName;
    case AuthStage.error:
      return location == AppRoutes.error ? null : AppRoutes.error;
    case AuthStage.userReady:
      // While userReady, only redirect away from pre-app locations; everything
      // else (tabs + pushed detail routes + pending deep links) is allowed.
      if (location == AppRoutes.splash ||
          location.startsWith(AppRoutes.login) ||
          location.startsWith(AppRoutes.onboarding) ||
          location == AppRoutes.intro ||
          location == AppRoutes.error) {
        return AppRoutes.capture;
      }
      return null;
  }
}

/// First-install intro gate. Runs after [redirectForStage]. Exposed for testing.
@visibleForTesting
String? redirectForIntro({
  required AuthStage stage,
  required String location,
  required bool introCompleted,
}) {
  if (stage != AuthStage.unauthenticated) return null;
  if (introCompleted) {
    return location == AppRoutes.intro ? AppRoutes.login : null;
  }
  return location == AppRoutes.intro ? null : AppRoutes.intro;
}

/// Translates a platform `gostylens://` URI into an in-app location, applying
/// auth gating and stashing blocked destinations for later. Exposed for testing.
@visibleForTesting
String? redirectForDeepLinkUri(
  AuthStage stage,
  Uri uri, {
  DeepLinkParser? parser,
  void Function(DeepLinkDestination destination)? onStashPending,
  InviteCodeStore? inviteCodeStore,
  bool introCompleted = true,
}) {
  final linkParser = parser ?? DeepLinkParser();
  final inviteCode = linkParser.extractInviteCode(uri);
  if (inviteCode != null) {
    final store = inviteCodeStore ?? locator<InviteCodeStore>();
    unawaited(store.save(inviteCode));
  }

  final destination = linkParser.parseUri(uri);
  final target = destination != null
      ? locationForDestination(destination)
      : neutralLocationForStage(stage, introCompleted: introCompleted);

  final gated = redirectForStage(stage, target);
  final afterStage = gated ?? target;
  final introGated = redirectForIntro(
    stage: stage,
    location: afterStage,
    introCompleted: introCompleted,
  );
  final resolved = introGated ?? gated;

  if (resolved != null) {
    if (destination != null) {
      onStashPending?.call(destination);
    }
    final neutral = neutralLocationForStage(
      stage,
      introCompleted: introCompleted,
    );
    return redirectForIntro(
          stage: stage,
          location: redirectForStage(stage, neutral) ?? neutral,
          introCompleted: introCompleted,
        ) ??
        redirectForStage(stage, neutral) ??
        neutral;
  }

  // Redirect is always `go` semantics — detail routes must land on the shell
  // first, then push via [DeepLinkService.schedulePushDetail].
  if (stage == AuthStage.userReady &&
      destination != null &&
      isPushDetailTarget(destination.target)) {
    onStashPending?.call(destination);
    return semanticShellFor(destination.target);
  }

  return target;
}

String? _redirect(AuthFlowController auth, GoRouterState state) {
  if (auth.stage == AuthStage.userReady) {
    final pending = locator<DeepLinkService>().takePendingDestination();
    if (pending != null) {
      if (isPushDetailTarget(pending.destination.target)) {
        locator<DeepLinkService>().schedulePushDetail(pending.destination);
        return pending.shellLocation;
      }
      return locationForDestination(pending.destination);
    }
  }

  final introCompleted = locator<IntroWalkthroughStore>().hasCompleted;

  if (state.uri.scheme == DeepLinkParser.supportedScheme) {
    return redirectForDeepLinkUri(
      auth.stage,
      state.uri,
      onStashPending: locator<DeepLinkService>().stashPendingDestination,
      introCompleted: introCompleted,
    );
  }

  final stageRedirect = redirectForStage(auth.stage, state.matchedLocation);
  final afterStage = stageRedirect ?? state.matchedLocation;
  final introRedirect = redirectForIntro(
    stage: auth.stage,
    location: afterStage,
    introCompleted: introCompleted,
  );
  return introRedirect ?? stageRedirect;
}

/// A safe in-app location for the current [stage], used when a custom-scheme
/// URI cannot be parsed or auth blocks the intended destination.
@visibleForTesting
String neutralLocationForStage(
  AuthStage stage, {
  bool introCompleted = true,
}) =>
    switch (stage) {
      AuthStage.booting => AppRoutes.splash,
      AuthStage.unauthenticated =>
        introCompleted ? AppRoutes.login : AppRoutes.intro,
      AuthStage.onboarding => AppRoutes.onboardingName,
      AuthStage.error => AppRoutes.error,
      AuthStage.userReady => AppRoutes.capture,
    };

/// Current top-of-stack location, usable outside the widget tree.
String currentLocation() =>
    appRouter.routerDelegate.state.matchedLocation;

/// Whether the chat (style analysis) screen is currently on top.
bool isOnSessionRoute() => isSessionLocation(currentLocation());

/// Whether the chat for [sessionId] is the screen currently on top.
///
/// Matches the route path (`/session/:id`) and/or the session manager selection
/// so guards work even when the two are briefly out of sync.
@visibleForTesting
bool matchesViewingSession({
  required String location,
  required String sessionId,
  String? managerSessionId,
}) {
  if (!isSessionLocation(location)) return false;
  final normalized = sessionId.trim();
  final routeId = sessionIdFromLocation(location);
  if (routeId != null && routeId == normalized) return true;
  return managerSessionId != null && managerSessionId == normalized;
}

/// Used to suppress redundant deep-link/notification navigation.
bool isViewingSession(String sessionId) {
  if (!isOnSessionRoute()) return false;
  return matchesViewingSession(
    location: currentLocation(),
    sessionId: sessionId,
    managerSessionId:
        locator<StyleAnalysisSessionManager>().selectedSessionId,
  );
}
