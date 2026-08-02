import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:gostylens/core/config/dependency_injection.dart';
import 'package:gostylens/core/managers/style_analysis_session/index.dart';
import 'package:gostylens/navigation/app_routes.dart';

/// Pops a full-screen detail route, or lands on its semantic parent tab when
/// there is no stack beneath (e.g. broken deep-link stack).
void popDetailOrGoHome(BuildContext context, {Object? result}) {
  if (context.canPop()) {
    context.pop(result);
    return;
  }
  final location = GoRouterState.of(context).matchedLocation;
  context.go(semanticShellForLocation(location));
}

/// Leaves a session chat and always lands on History (sessions' semantic parent),
/// regardless of whether Capture or History pushed `/session`.
///
/// Uses [GoRouter.go] (not pop) so Capture-origin sessions do not flash Capture.
/// Refreshes the sessions list when it is still marked stale (e.g. when History
/// did not await the push and consume the stale flag itself).
void leaveSessionToHistory(BuildContext context) {
  final router = GoRouter.of(context);
  final sessionManager = locator<StyleAnalysisSessionManager>();

  router.go(AppRoutes.history);

  if (sessionManager.sessionsListStale) {
    sessionManager.consumeSessionsListStale();
    sessionManager.refreshSessionsPreservingPagination(silent: true);
  }
}

/// After a new session is persisted, rewrite `/session` → `/session/:id` without
/// remounting the chat (session routes share a stable [Page] key).
void replaceNewSessionRoute(BuildContext context, String sessionId) {
  if (sessionId.isEmpty) return;
  final location = GoRouterState.of(context).matchedLocation;
  if (location != AppRoutes.sessionNew) return;
  context.replace(AppRoutes.session(sessionId));
}
