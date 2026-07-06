import 'package:flutter/widgets.dart';
import 'package:gostylens/core/config/dependency_injection.dart';
import 'package:gostylens/core/managers/style_analysis_session/index.dart';
import 'package:gostylens/core/navigation/deep_link/deep_link_destination.dart';
import 'package:gostylens/navigation/app_router.dart';
import 'package:gostylens/navigation/app_routes.dart';

/// Translates a [DeepLinkDestination] into GoRouter navigation.
///
/// Tabs use `go` (idempotent branch switch). Full-screen details use `push` on
/// top of the tab shell, guarded so repeat deliveries of the same link (a known
/// iOS custom-scheme quirk) don't stack duplicate pages.
class DeepLinkRouter {
  void navigate(DeepLinkDestination destination) {
    switch (destination.target) {
      case DeepLinkTarget.capture:
        appRouter.go(AppRoutes.capture);
      case DeepLinkTarget.closet:
        appRouter.go(AppRoutes.closet);
      case DeepLinkTarget.history:
        appRouter.go(AppRoutes.history);
      case DeepLinkTarget.session:
        final sessionId = destination.sessionId;
        if (sessionId == null || sessionId.isEmpty) {
          appRouter.go(AppRoutes.capture);
          return;
        }
        if (isViewingSession(sessionId)) return;
        locator<StyleAnalysisSessionManager>().setSelectedSessionId(sessionId);
        _pushDetail(
          AppRoutes.session(sessionId),
          shellLocation: semanticShellFor(DeepLinkTarget.session),
        );
      case DeepLinkTarget.paywall:
        _pushDetail(
          AppRoutes.paywall,
          shellLocation: semanticShellFor(DeepLinkTarget.paywall),
        );
      case DeepLinkTarget.billing:
        _pushDetail(
          AppRoutes.billing,
          shellLocation: semanticShellFor(DeepLinkTarget.billing),
        );
    }
  }

  /// Pushes a full-screen route, ensuring a tab shell sits beneath it so the
  /// back button works, and skipping if we're already on [location].
  void _pushDetail(String location, {required String shellLocation}) {
    final current = currentLocation();
    if (current == location) return;

    if (!isTabLocation(current)) {
      appRouter.go(shellLocation);
    }
    appRouter.push(location);
  }

  /// Defers [navigate] until after the current redirect/frame so a tab shell
  /// can sit beneath the pushed detail route.
  void schedulePushDetail(DeepLinkDestination destination) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      navigate(destination);
    });
  }
}
