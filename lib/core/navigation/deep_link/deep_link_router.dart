import 'package:flutter/material.dart';
import 'package:gostylens/core/config/dependency_injection.dart';
import 'package:gostylens/core/managers/style_analysis_session/index.dart';
import 'package:gostylens/core/navigation/app_navigation_keys.dart';
import 'package:gostylens/core/navigation/deep_link/deep_link_destination.dart';
import 'package:gostylens/core/navigation/home_tab_controller.dart';
import 'package:gostylens/core/navigation/style_analysis_route_tracker.dart';
import 'package:gostylens/pages/billing_plan.dart';
import 'package:gostylens/pages/paywall.dart';
import 'package:gostylens/pages/style_analysis.dart';

class DeepLinkRouter {
  DeepLinkRouter({
    StyleAnalysisRouteTracker? routeTracker,
    HomeTabController? homeTabController,
  })  : _routeTracker = routeTracker ?? locator<StyleAnalysisRouteTracker>(),
        _homeTabController = homeTabController ?? locator<HomeTabController>();

  final StyleAnalysisRouteTracker _routeTracker;
  final HomeTabController _homeTabController;

  void navigate(DeepLinkDestination destination) {
    final navigator = rootNavigatorKey.currentState;
    if (navigator == null) return;

    switch (destination.target) {
      case DeepLinkTarget.capture:
        _navigateToTab(navigator, HomeTabController.captureIndex);
      case DeepLinkTarget.closet:
        _navigateToTab(navigator, HomeTabController.closetIndex);
      case DeepLinkTarget.history:
        _navigateToTab(navigator, HomeTabController.historyIndex);
      case DeepLinkTarget.session:
        final sessionId = destination.sessionId;
        if (sessionId == null || sessionId.isEmpty) {
          _navigateToTab(navigator, HomeTabController.captureIndex);
          return;
        }
        _openSession(navigator, sessionId);
      case DeepLinkTarget.paywall:
        navigator.push(
          MaterialPageRoute(builder: (_) => const PaywallPage()),
        );
      case DeepLinkTarget.billing:
        navigator.push(
          MaterialPageRoute(builder: (_) => BillingPlanPage()),
        );
    }
  }

  void _navigateToTab(NavigatorState navigator, int tabIndex) {
    navigator.popUntil((route) => route.isFirst);
    _homeTabController.setTab(tabIndex);
  }

  void _openSession(NavigatorState navigator, String sessionId) {
    if (_isViewingSession(sessionId)) return;

    navigator.popUntil((route) => route.isFirst);
    locator<StyleAnalysisSessionManager>().setSelectedSessionId(sessionId);
    navigator.push(
      MaterialPageRoute(builder: (_) => const StyleAnalysisPage()),
    );
  }

  bool _isViewingSession(String sessionId) {
    if (_routeTracker.isViewingSession(sessionId)) return true;

    if (!_routeTracker.isOnChatScreen) return false;

    final activeSessionId =
        locator<StyleAnalysisSessionManager>().selectedSessionId;
    return activeSessionId != null && activeSessionId == sessionId;
  }
}
