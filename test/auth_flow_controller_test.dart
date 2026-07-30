import 'package:flutter_test/flutter_test.dart';
import 'package:gostylens/models/user_state.dart';
import 'package:gostylens/navigation/auth_flow_controller.dart';

void main() {
  group('deriveAuthStage', () {
    test('returns booting before splash reveal completes', () {
      final stage = deriveAuthStage(
        splashRevealCompleted: false,
        authResolved: true,
        hasSession: true,
        hasUser: true,
        fetchStatus: UserFetchStatus.ready,
      );

      expect(stage, AuthStage.booting);
    });

    test('returns booting before auth is resolved', () {
      final stage = deriveAuthStage(
        splashRevealCompleted: true,
        authResolved: false,
        hasSession: false,
        hasUser: false,
        fetchStatus: UserFetchStatus.initial,
      );

      expect(stage, AuthStage.booting);
    });

    test('returns unauthenticated when session is absent', () {
      final stage = deriveAuthStage(
        splashRevealCompleted: true,
        authResolved: true,
        hasSession: false,
        hasUser: false,
        fetchStatus: UserFetchStatus.ready,
      );

      expect(stage, AuthStage.unauthenticated);
    });

    test('returns userReady while refreshing with existing user', () {
      final stage = deriveAuthStage(
        splashRevealCompleted: true,
        authResolved: true,
        hasSession: true,
        hasUser: true,
        fetchStatus: UserFetchStatus.loading,
      );

      expect(stage, AuthStage.userReady);
    });

    test('returns userReady on refresh error with existing user', () {
      final stage = deriveAuthStage(
        splashRevealCompleted: true,
        authResolved: true,
        hasSession: true,
        hasUser: true,
        fetchStatus: UserFetchStatus.error,
      );

      expect(stage, AuthStage.userReady);
    });

    test('returns onboarding when profile is missing', () {
      final stage = deriveAuthStage(
        splashRevealCompleted: true,
        authResolved: true,
        hasSession: true,
        hasUser: false,
        fetchStatus: UserFetchStatus.onboarding,
      );

      expect(stage, AuthStage.onboarding);
    });

    test('returns error when initial profile fetch fails without user', () {
      final stage = deriveAuthStage(
        splashRevealCompleted: true,
        authResolved: true,
        hasSession: true,
        hasUser: false,
        fetchStatus: UserFetchStatus.error,
      );

      expect(stage, AuthStage.error);
    });
  });
}
