import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gostylens/core/managers/style_analysis_session/index.dart';
import 'package:gostylens/models/api_responses/api_response.dart';
import 'package:gostylens/models/api_responses/user.dart' as app_user;
import 'package:gostylens/models/user_state.dart';
import 'package:gostylens/navigation/auth_flow_controller.dart';
import 'package:gostylens/navigation/auth_flow_user_state.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthFlowController sign-out integration', () {
    late _FakeGoTrueClient goTrue;
    late _RecordingAuthFlowUserState userState;
    late _FakeSessionManager sessionManager;
    late AuthFlowController? controller;

    setUp(() {
      goTrue = _FakeGoTrueClient();
      userState = _RecordingAuthFlowUserState();
      sessionManager = _FakeSessionManager();
      final getIt = GetIt.instance;
      if (!getIt.isRegistered<StyleAnalysisSessionManager>()) {
        getIt.registerSingleton<StyleAnalysisSessionManager>(sessionManager);
      }
      controller = AuthFlowController(
        client: _FakeSupabaseClient(goTrue),
        userState: userState,
        splashFallbackDuration: Duration.zero,
      );
    });

    tearDown(() {
      controller?.dispose();
      final getIt = GetIt.instance;
      if (getIt.isRegistered<StyleAnalysisSessionManager>()) {
        getIt.unregister<StyleAnalysisSessionManager>();
      }
    });

    test('clears user state once when signedOut is emitted', () async {
      controller!.start();
      await pumpEventQueue();

      goTrue.emit(const AuthState(AuthChangeEvent.signedOut, null));
      await pumpEventQueue();

      expect(userState.clearStateCallCount, 1);
      expect(sessionManager.clearMessageCacheCallCount, 1);
      expect(controller!.stage, AuthStage.unauthenticated);
    });

    test('clears user state when initialSession has no session', () async {
      controller!.start();
      await pumpEventQueue();

      goTrue.emit(const AuthState(AuthChangeEvent.initialSession, null));
      await pumpEventQueue();

      expect(userState.clearStateCallCount, 1);
      expect(sessionManager.clearMessageCacheCallCount, 1);
      expect(controller!.stage, AuthStage.unauthenticated);
    });

    test('does not clear user state on signedIn', () async {
      controller!.start();
      await pumpEventQueue();

      goTrue.emit(AuthState(AuthChangeEvent.signedIn, _fakeSession()));
      await pumpEventQueue();

      expect(userState.clearStateCallCount, 0);
      expect(sessionManager.clearMessageCacheCallCount, 0);
    });
  });
}

class _FakeSessionManager extends Fake implements StyleAnalysisSessionManager {
  int clearMessageCacheCallCount = 0;

  @override
  void clearMessageCache() {
    clearMessageCacheCallCount++;
  }
}

Session _fakeSession() {
  return Session(
    accessToken: 'access-token',
    tokenType: 'bearer',
    user: User(
      id: 'user-id',
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: DateTime.utc(2024).toIso8601String(),
    ),
  );
}

class _RecordingAuthFlowUserState extends ChangeNotifier
    implements AuthFlowUserState {
  int clearStateCallCount = 0;

  @override
  UserOperationState operationState = const UserOperationState();

  @override
  app_user.User? currentUser;

  @override
  ErrorData? lastError;

  @override
  Future<void> clearState() async {
    clearStateCallCount++;
    currentUser = null;
    operationState = const UserOperationState();
    notifyListeners();
  }

  @override
  Future<void> fetchCurrentUser() async {}
}

class _FakeGoTrueClient extends Fake implements GoTrueClient {
  Session? session;
  final StreamController<AuthState> _controller =
      StreamController<AuthState>.broadcast();

  @override
  Session? get currentSession => session;

  @override
  Stream<AuthState> get onAuthStateChange => _controller.stream;

  void emit(AuthState state) {
    session = state.session;
    _controller.add(state);
  }
}

class _FakeSupabaseClient extends Fake implements SupabaseClient {
  _FakeSupabaseClient(this._auth);

  final GoTrueClient _auth;

  @override
  GoTrueClient get auth => _auth;
}
