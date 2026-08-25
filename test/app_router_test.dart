import 'package:flutter_test/flutter_test.dart';
import 'package:gostylens/core/managers/invite_code_store.dart';
import 'package:gostylens/core/navigation/deep_link/deep_link_destination.dart';
import 'package:gostylens/navigation/app_router.dart';
import 'package:gostylens/navigation/app_routes.dart';
import 'package:gostylens/navigation/auth_flow_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('redirectForStage', () {
    test('booting always lands on splash', () {
      expect(redirectForStage(AuthStage.booting, '/capture'), AppRoutes.splash);
      expect(redirectForStage(AuthStage.booting, AppRoutes.splash), isNull);
    });

    test('unauthenticated allows login, otp, and intro', () {
      expect(
        redirectForStage(AuthStage.unauthenticated, '/capture'),
        AppRoutes.login,
      );
      expect(redirectForStage(AuthStage.unauthenticated, AppRoutes.login), isNull);
      expect(redirectForStage(AuthStage.unauthenticated, AppRoutes.otp), isNull);
      expect(redirectForStage(AuthStage.unauthenticated, AppRoutes.intro), isNull);
    });

    test('onboarding allows both onboarding steps', () {
      expect(
        redirectForStage(AuthStage.onboarding, '/capture'),
        AppRoutes.onboardingName,
      );
      expect(
        redirectForStage(AuthStage.onboarding, AppRoutes.onboardingName),
        isNull,
      );
      expect(
        redirectForStage(AuthStage.onboarding, AppRoutes.onboardingGender),
        isNull,
      );
    });

    test('error always lands on error', () {
      expect(redirectForStage(AuthStage.error, '/capture'), AppRoutes.error);
      expect(redirectForStage(AuthStage.error, AppRoutes.error), isNull);
    });

    test('userReady leaves pre-app locations but allows app routes', () {
      expect(
        redirectForStage(AuthStage.userReady, AppRoutes.splash),
        AppRoutes.capture,
      );
      expect(
        redirectForStage(AuthStage.userReady, AppRoutes.login),
        AppRoutes.capture,
      );
      expect(
        redirectForStage(AuthStage.userReady, AppRoutes.onboardingName),
        AppRoutes.capture,
      );
      expect(
        redirectForStage(AuthStage.userReady, AppRoutes.intro),
        AppRoutes.capture,
      );
      expect(
        redirectForStage(AuthStage.userReady, AppRoutes.error),
        AppRoutes.capture,
      );

      expect(redirectForStage(AuthStage.userReady, AppRoutes.capture), isNull);
      expect(redirectForStage(AuthStage.userReady, AppRoutes.closet), isNull);
      expect(redirectForStage(AuthStage.userReady, AppRoutes.billing), isNull);
      expect(
        redirectForStage(AuthStage.userReady, AppRoutes.session('abc')),
        isNull,
      );
    });
  });

  group('locationForDestination', () {
    test('maps tab destinations', () {
      expect(locationForDestination(DeepLinkDestination.capture), AppRoutes.capture);
      expect(locationForDestination(DeepLinkDestination.closet), AppRoutes.closet);
      expect(locationForDestination(DeepLinkDestination.history), AppRoutes.history);
    });

    test('maps detail destinations', () {
      expect(locationForDestination(DeepLinkDestination.paywall), AppRoutes.paywall);
      expect(locationForDestination(DeepLinkDestination.billing), AppRoutes.billing);
    });

    test('maps session by id, falling back to capture when empty', () {
      expect(
        locationForDestination(DeepLinkDestination.session('s1')),
        AppRoutes.session('s1'),
      );
      expect(
        locationForDestination(DeepLinkDestination.session('')),
        AppRoutes.capture,
      );
    });
  });

  group('redirectForIntro', () {
    test('unauthenticated + incomplete sends non-intro to intro', () {
      expect(
        redirectForIntro(
          stage: AuthStage.unauthenticated,
          location: AppRoutes.login,
          introCompleted: false,
        ),
        AppRoutes.intro,
      );
      expect(
        redirectForIntro(
          stage: AuthStage.unauthenticated,
          location: AppRoutes.intro,
          introCompleted: false,
        ),
        isNull,
      );
    });

    test('completed intro on intro route returns login', () {
      expect(
        redirectForIntro(
          stage: AuthStage.unauthenticated,
          location: AppRoutes.intro,
          introCompleted: true,
        ),
        AppRoutes.login,
      );
      expect(
        redirectForIntro(
          stage: AuthStage.unauthenticated,
          location: AppRoutes.login,
          introCompleted: true,
        ),
        isNull,
      );
    });

    test('non-unauthenticated stages ignore intro flag', () {
      expect(
        redirectForIntro(
          stage: AuthStage.userReady,
          location: AppRoutes.capture,
          introCompleted: false,
        ),
        isNull,
      );
      expect(
        redirectForIntro(
          stage: AuthStage.booting,
          location: AppRoutes.splash,
          introCompleted: false,
        ),
        isNull,
      );
    });
  });

  group('redirectForDeepLinkUri', () {
    test('gostylens://history + userReady returns /history', () {
      expect(
        redirectForDeepLinkUri(
          AuthStage.userReady,
          Uri.parse('gostylens://history'),
        ),
        AppRoutes.history,
      );
    });

    test('gostylens:/history path-only + userReady returns /history', () {
      expect(
        redirectForDeepLinkUri(
          AuthStage.userReady,
          Uri.parse('gostylens:/history'),
        ),
        AppRoutes.history,
      );
    });

    test('gostylens://billing + unauthenticated stashes and returns /login', () {
      DeepLinkDestination? stashed;
      expect(
        redirectForDeepLinkUri(
          AuthStage.unauthenticated,
          Uri.parse('gostylens://billing'),
          onStashPending: (d) => stashed = d,
        ),
        AppRoutes.login,
      );
      expect(stashed?.target, DeepLinkTarget.billing);
    });

    test('gostylens://billing + unauthenticated + incomplete intro → /intro', () {
      DeepLinkDestination? stashed;
      expect(
        redirectForDeepLinkUri(
          AuthStage.unauthenticated,
          Uri.parse('gostylens://billing'),
          onStashPending: (d) => stashed = d,
          introCompleted: false,
        ),
        AppRoutes.intro,
      );
      expect(stashed?.target, DeepLinkTarget.billing);
    });

    test('gostylens:// empty host + userReady returns /capture', () {
      expect(
        redirectForDeepLinkUri(
          AuthStage.userReady,
          Uri.parse('gostylens://'),
        ),
        AppRoutes.capture,
      );
    });

    test('gostylens://billing + booting stashes and returns /splash', () {
      DeepLinkDestination? stashed;
      expect(
        redirectForDeepLinkUri(
          AuthStage.booting,
          Uri.parse('gostylens://billing'),
          onStashPending: (d) => stashed = d,
        ),
        AppRoutes.splash,
      );
      expect(stashed?.target, DeepLinkTarget.billing);
    });

    test('gostylens://paywall + userReady stashes and returns /capture', () {
      DeepLinkDestination? stashed;
      expect(
        redirectForDeepLinkUri(
          AuthStage.userReady,
          Uri.parse('gostylens://paywall'),
          onStashPending: (d) => stashed = d,
        ),
        AppRoutes.capture,
      );
      expect(stashed?.target, DeepLinkTarget.paywall);
    });

    test('gostylens://billing + userReady stashes and returns /capture', () {
      DeepLinkDestination? stashed;
      expect(
        redirectForDeepLinkUri(
          AuthStage.userReady,
          Uri.parse('gostylens://billing'),
          onStashPending: (d) => stashed = d,
        ),
        AppRoutes.capture,
      );
      expect(stashed?.target, DeepLinkTarget.billing);
    });

    test('gostylens://session/s1 + userReady stashes and returns /history', () {
      DeepLinkDestination? stashed;
      expect(
        redirectForDeepLinkUri(
          AuthStage.userReady,
          Uri.parse('gostylens://session/s1'),
          onStashPending: (d) => stashed = d,
        ),
        AppRoutes.history,
      );
      expect(stashed?.target, DeepLinkTarget.session);
      expect(stashed?.sessionId, 's1');
    });

    test('gostylens://invite?code=X persists code and returns stage-neutral', () async {
      SharedPreferences.setMockInitialValues({});
      final store = InviteCodeStore();
      DeepLinkDestination? stashed;

      expect(
        redirectForDeepLinkUri(
          AuthStage.unauthenticated,
          Uri.parse('gostylens://invite?code=summer50'),
          onStashPending: (d) => stashed = d,
          inviteCodeStore: store,
        ),
        AppRoutes.login,
      );
      expect(stashed, isNull);
      // Allow unawaited save to flush
      await Future<void>.delayed(Duration.zero);
      expect(await store.read(), 'SUMMER50');
    });

    test('gostylens://capture?code=X keeps capture destination and stores code', () async {
      SharedPreferences.setMockInitialValues({});
      final store = InviteCodeStore();

      expect(
        redirectForDeepLinkUri(
          AuthStage.userReady,
          Uri.parse('gostylens://capture?code=VIP'),
          inviteCodeStore: store,
        ),
        AppRoutes.capture,
      );
      await Future<void>.delayed(Duration.zero);
      expect(await store.read(), 'VIP');
    });
  });

  group('neutralLocationForStage', () {
    test('maps each auth stage to a safe default', () {
      expect(neutralLocationForStage(AuthStage.booting), AppRoutes.splash);
      expect(
        neutralLocationForStage(AuthStage.unauthenticated),
        AppRoutes.login,
      );
      expect(
        neutralLocationForStage(
          AuthStage.unauthenticated,
          introCompleted: false,
        ),
        AppRoutes.intro,
      );
      expect(
        neutralLocationForStage(AuthStage.onboarding),
        AppRoutes.onboardingName,
      );
      expect(neutralLocationForStage(AuthStage.error), AppRoutes.error);
      expect(neutralLocationForStage(AuthStage.userReady), AppRoutes.capture);
    });
  });

  group('location helpers', () {
    test('isTabLocation', () {
      expect(isTabLocation(AppRoutes.capture), isTrue);
      expect(isTabLocation(AppRoutes.billing), isFalse);
    });

    test('isPushDetailLocation', () {
      expect(isPushDetailLocation(AppRoutes.paywall), isTrue);
      expect(isPushDetailLocation(AppRoutes.billing), isTrue);
      expect(isPushDetailLocation(AppRoutes.session('x')), isTrue);
      expect(isPushDetailLocation(AppRoutes.capture), isFalse);
    });

    test('isPushDetailTarget', () {
      expect(isPushDetailTarget(DeepLinkTarget.paywall), isTrue);
      expect(isPushDetailTarget(DeepLinkTarget.history), isFalse);
    });

    test('isSessionLocation', () {
      expect(isSessionLocation(AppRoutes.sessionNew), isTrue);
      expect(isSessionLocation(AppRoutes.session('x')), isTrue);
      expect(isSessionLocation(AppRoutes.capture), isFalse);
    });

    test('semanticShellFor', () {
      expect(semanticShellFor(DeepLinkTarget.session), AppRoutes.history);
      expect(semanticShellFor(DeepLinkTarget.paywall), AppRoutes.capture);
      expect(semanticShellFor(DeepLinkTarget.billing), AppRoutes.capture);
      expect(semanticShellFor(DeepLinkTarget.history), AppRoutes.capture);
    });

    test('semanticShellForLocation', () {
      expect(semanticShellForLocation(AppRoutes.session('x')), AppRoutes.history);
      expect(semanticShellForLocation(AppRoutes.paywall), AppRoutes.capture);
      expect(semanticShellForLocation(AppRoutes.billing), AppRoutes.capture);
    });

    test('sessionIdFromLocation', () {
      expect(sessionIdFromLocation(AppRoutes.sessionNew), isNull);
      expect(sessionIdFromLocation(AppRoutes.session('s1')), 's1');
    });

    test('matchesViewingSession', () {
      expect(
        matchesViewingSession(
          location: AppRoutes.session('s1'),
          sessionId: 's1',
          managerSessionId: null,
        ),
        isTrue,
      );
      expect(
        matchesViewingSession(
          location: AppRoutes.session('s1'),
          sessionId: 's2',
          managerSessionId: null,
        ),
        isFalse,
      );
      expect(
        matchesViewingSession(
          location: AppRoutes.capture,
          sessionId: 's1',
          managerSessionId: 's1',
        ),
        isFalse,
      );
      expect(
        matchesViewingSession(
          location: AppRoutes.sessionNew,
          sessionId: 's1',
          managerSessionId: 's1',
        ),
        isTrue,
      );
    });
  });
}
