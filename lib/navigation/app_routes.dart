import 'package:gostylens/core/navigation/deep_link/deep_link_destination.dart';

/// Canonical location strings for the app's GoRouter configuration.
///
/// Keeping these in one place lets deep links, redirects, and call sites share
/// the exact same paths without magic strings scattered across the codebase.
class AppRoutes {
  const AppRoutes._();

  static const splash = '/splash';
  static const login = '/login';
  static const otp = '/login/otp';
  static const onboarding = '/onboarding';
  static const onboardingName = '/onboarding/name';
  static const onboardingGender = '/onboarding/gender';
  static const error = '/error';

  // Tab (shell branch) locations.
  static const closet = '/closet';
  static const capture = '/capture';
  static const history = '/history';

  // Full-screen routes pushed over the tab shell.
  static const sessionNew = '/session';
  static const sessionPattern = '/session/:id';
  static const paywall = '/paywall';
  static const billing = '/billing';
  static const profile = '/profile';

  static String session(String id) => '/session/$id';

  /// Tab branch locations that the bottom nav switches between.
  static const tabLocations = {closet, capture, history};
}

/// Maps a parsed [DeepLinkDestination] to its GoRouter location string.
String locationForDestination(DeepLinkDestination destination) {
  return switch (destination.target) {
    DeepLinkTarget.capture => AppRoutes.capture,
    DeepLinkTarget.closet => AppRoutes.closet,
    DeepLinkTarget.history => AppRoutes.history,
    DeepLinkTarget.paywall => AppRoutes.paywall,
    DeepLinkTarget.billing => AppRoutes.billing,
    DeepLinkTarget.session =>
      (destination.sessionId != null && destination.sessionId!.isNotEmpty)
          ? AppRoutes.session(destination.sessionId!)
          : AppRoutes.capture,
  };
}

/// Whether [location] targets one of the bottom-nav tab branches.
bool isTabLocation(String location) => AppRoutes.tabLocations.contains(location);

/// Whether [location] is the new-session route or an existing-session route.
bool isSessionLocation(String location) =>
    location == AppRoutes.sessionNew ||
    location.startsWith('${AppRoutes.sessionNew}/');

/// Extracts the session id from `/session/:id`, or null for `/session` (new).
String? sessionIdFromLocation(String location) {
  if (location == AppRoutes.sessionNew) return null;
  if (!location.startsWith('${AppRoutes.sessionNew}/')) return null;
  final id = location.substring('${AppRoutes.sessionNew}/'.length);
  return id.isEmpty ? null : id;
}

/// Full-screen routes that must be [GoRouter.push]ed over the tab shell, never
/// reached via redirect `go` (which would leave nothing to pop back to).
bool isPushDetailTarget(DeepLinkTarget target) => switch (target) {
      DeepLinkTarget.paywall ||
      DeepLinkTarget.billing ||
      DeepLinkTarget.session =>
        true,
      _ => false,
    };

bool isPushDetailLocation(String location) =>
    location == AppRoutes.paywall ||
    location == AppRoutes.billing ||
    isSessionLocation(location);

/// Natural parent tab for a push-detail deep link — mirrors normal in-app paths.
String semanticShellFor(DeepLinkTarget target) => switch (target) {
      DeepLinkTarget.session => AppRoutes.history,
      DeepLinkTarget.paywall || DeepLinkTarget.billing => AppRoutes.capture,
      _ => AppRoutes.capture,
    };

/// [semanticShellFor] derived from a push-detail location string.
String semanticShellForLocation(String location) {
  if (isSessionLocation(location)) return AppRoutes.history;
  if (location == AppRoutes.paywall || location == AppRoutes.billing) {
    return AppRoutes.capture;
  }
  return AppRoutes.capture;
}
