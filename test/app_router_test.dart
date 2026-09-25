import 'package:flutter_test/flutter_test.dart';
import 'package:gostylens/core/managers/invite_code_manager.dart';
import 'package:gostylens/core/navigation/deep_link/deep_link_destination.dart';
import 'package:gostylens/core/prefs/local_prefs_service.dart';
import 'package:gostylens/navigation/app_router.dart';
import 'package:gostylens/navigation/app_routes.dart';
import 'package:gostylens/navigation/auth_flow_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<InviteCodeManager> inviteManagerForTest() async {
  SharedPreferences.setMockInitialValues({});
  final sp = await SharedPreferences.getInstance();
  final prefs = LocalPrefsService(sp);
  await prefs.warm();
  return InviteCodeManager(prefs: prefs);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
      expect(
        redirectForStage(AuthStage.unauthenticated, AppRoutes.login),
        isNull,
      );
      expect(
        redirectForStage(AuthStage.unauthenticated, AppRoutes.otp),
        isNull,
      );
      expect(
        redirectForStage(AuthStage.unauthenticated, AppRoutes.intro),
        isNull,
      );
    });

    test('onboarding allows all onboarding steps', () {
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
      expect(
        redirectForStage(AuthStage.onboarding, AppRoutes.onboardingEmail),
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
        redirectForStage(AuthStage.userReady, AppRoutes.profileNotifications),
        isNull,
      );
      expect(
        redirectForStage(AuthStage.userReady, AppRoutes.session('abc')),
        isNull,
      );
      expect(
        redirectForStage(AuthStage.userReady, AppRoutes.closetItem('c1')),
        isNull,
      );
    });
  });

  group('locationForDestination', () {
    test('maps tab destinations', () {
      expect(
        locationForDestination(DeepLinkDestination.capture),
        AppRoutes.capture,
      );
      expect(
        locationForDestination(DeepLinkDestination.closet),
        AppRoutes.closet,
      );
      expect(
        locationForDestination(DeepLinkDestination.history),
        AppRoutes.history,
      );
    });

    test('maps detail destinations', () {
      expect(
        locationForDestination(DeepLinkDestination.paywall),
        AppRoutes.paywall,
      );
      expect(
        locationForDestination(DeepLinkDestination.billing),
        AppRoutes.billing,
      );
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

    test(
      'gostylens://billing + unauthenticated stashes and returns /login',
      () {
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
      },
    );

    test(
      'gostylens://billing + unauthenticated + incomplete intro → /intro',
      () {
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
      },
    );

    test('gostylens:// empty host + userReady returns /capture', () {
      expect(
        redirectForDeepLinkUri(AuthStage.userReady, Uri.parse('gostylens://')),
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

    test(
      'gostylens://invite?code=X persists code and returns stage-neutral',
      () async {
        final manager = await inviteManagerForTest();
        DeepLinkDestination? stashed;

        expect(
          redirectForDeepLinkUri(
            AuthStage.unauthenticated,
            Uri.parse('gostylens://invite?code=summer50'),
            onStashPending: (d) => stashed = d,
            inviteCodeManager: manager,
          ),
          AppRoutes.login,
        );
        expect(stashed, isNull);
        // Allow unawaited save to flush
        await Future<void>.delayed(Duration.zero);
        expect(await manager.read(), 'SUMMER50');
      },
    );

    test(
      'gostylens://capture?code=X keeps capture destination and stores code',
      () async {
        final manager = await inviteManagerForTest();

        expect(
          redirectForDeepLinkUri(
            AuthStage.userReady,
            Uri.parse('gostylens://capture?code=VIP'),
            inviteCodeManager: manager,
          ),
          AppRoutes.capture,
        );
        await Future<void>.delayed(Duration.zero);
        expect(await manager.read(), 'VIP');
      },
    );

    test('https://gostylens.app/history + userReady returns /history', () {
      expect(
        redirectForDeepLinkUri(
          AuthStage.userReady,
          Uri.parse('https://gostylens.app/history'),
        ),
        AppRoutes.history,
      );
    });

    test(
      'https://gostylens.app/session/s1 + userReady stashes and returns /history',
      () {
        DeepLinkDestination? stashed;
        expect(
          redirectForDeepLinkUri(
            AuthStage.userReady,
            Uri.parse('https://gostylens.app/session/s1'),
            onStashPending: (d) => stashed = d,
          ),
          AppRoutes.history,
        );
        expect(stashed?.target, DeepLinkTarget.session);
        expect(stashed?.sessionId, 's1');
      },
    );

    test(
      'https://gostylens.app/invite?code=X persists code and returns stage-neutral',
      () async {
        final manager = await inviteManagerForTest();
        DeepLinkDestination? stashed;

        expect(
          redirectForDeepLinkUri(
            AuthStage.unauthenticated,
            Uri.parse('https://gostylens.app/invite?code=summer50'),
            onStashPending: (d) => stashed = d,
            inviteCodeManager: manager,
          ),
          AppRoutes.login,
        );
        expect(stashed, isNull);
        await Future<void>.delayed(Duration.zero);
        expect(await manager.read(), 'SUMMER50');
      },
    );
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
      expect(isPushDetailLocation(AppRoutes.closetItem('c1')), isTrue);
      expect(isPushDetailLocation(AppRoutes.closet), isFalse);
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

    test('isCaptureLocation', () {
      expect(isCaptureLocation(AppRoutes.capture), isTrue);
      expect(isCaptureLocation('${AppRoutes.capture}/nested'), isTrue);
      expect(isCaptureLocation(AppRoutes.closet), isFalse);
      expect(isCaptureLocation(AppRoutes.history), isFalse);
      expect(isCaptureLocation(AppRoutes.session('x')), isFalse);
    });

    test('semanticShellFor', () {
      expect(semanticShellFor(DeepLinkTarget.session), AppRoutes.history);
      expect(semanticShellFor(DeepLinkTarget.paywall), AppRoutes.capture);
      expect(semanticShellFor(DeepLinkTarget.billing), AppRoutes.capture);
      expect(semanticShellFor(DeepLinkTarget.history), AppRoutes.capture);
    });

    test('semanticShellForLocation', () {
      expect(
        semanticShellForLocation(AppRoutes.session('x')),
        AppRoutes.history,
      );
      expect(semanticShellForLocation(AppRoutes.paywall), AppRoutes.capture);
      expect(semanticShellForLocation(AppRoutes.billing), AppRoutes.capture);
      expect(
        semanticShellForLocation(AppRoutes.closetItem('c1')),
        AppRoutes.closet,
      );
    });

    test('closetItemIdFromLocation', () {
      expect(closetItemIdFromLocation(AppRoutes.closetItem('c1')), 'c1');
      expect(closetItemIdFromLocation(AppRoutes.closet), isNull);
      expect(closetItemIdFromLocation('/closet-item/'), isNull);
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
