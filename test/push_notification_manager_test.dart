import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostylens/core/managers/push_messaging.dart';
import 'package:gostylens/core/managers/push_notification_manager.dart';
import 'package:gostylens/core/services/api_service/push_notification_api_service.dart';
import 'package:gostylens/models/api_responses/api_response.dart';

class FakePushMessaging extends PushMessaging {
  AuthorizationStatus status = AuthorizationStatus.notDetermined;
  int requestCount = 0;
  int openSettingsCount = 0;
  String? token = 'tok';

  @override
  Future<AuthorizationStatus> authorizationStatus() async => status;

  @override
  Future<AuthorizationStatus> requestPermission() async {
    requestCount += 1;
    return status;
  }

  @override
  Future<String?> getToken() async => token;

  @override
  Stream<String> get onTokenRefresh => const Stream.empty();

  @override
  Future<void> configureForegroundPresentation() async {}

  @override
  Future<bool> openAppNotificationSettings() async {
    openSettingsCount += 1;
    return true;
  }
}

class FakePushApi extends PushNotificationApiService {
  int upserts = 0;
  int deletes = 0;
  String? lastTimezone;

  @override
  Future<ApiResponse<void>> upsertToken({
    required String token,
    required String platform,
    String? timezone,
  }) async {
    upserts += 1;
    lastTimezone = timezone;
    return ApiResponse.success(null);
  }

  @override
  Future<ApiResponse<void>> deleteToken(String token) async {
    deletes += 1;
    return ApiResponse.success(null);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakePushMessaging messaging;
  late FakePushApi api;
  late PushNotificationManager manager;

  setUp(() {
    messaging = FakePushMessaging();
    api = FakePushApi();
    manager = PushNotificationManager(
      apiService: api,
      messaging: messaging,
      resolveTimezone: () async => 'Europe/Amsterdam',
    );
  });

  test('authorized status turns the switch on and registers a token', () async {
    messaging.status = AuthorizationStatus.authorized;
    await manager.refreshAuthorization();

    expect(manager.isAuthorized, isTrue);
    expect(api.upserts, 1);
    expect(api.lastTimezone, 'Europe/Amsterdam');
  });

  test('denied status leaves the switch off', () async {
    messaging.status = AuthorizationStatus.denied;
    await manager.refreshAuthorization();

    expect(manager.isAuthorized, isFalse);
    expect(api.upserts, 0);
  });

  test('setEnabled(true) when denied opens settings and stays off', () async {
    messaging.status = AuthorizationStatus.denied;
    await manager.refreshAuthorization();

    await manager.setEnabled(true);

    expect(messaging.openSettingsCount, 1);
    expect(messaging.requestCount, 0);
    expect(manager.isAuthorized, isFalse);
  });

  test('setEnabled(true) when notDetermined requests permission', () async {
    messaging.status = AuthorizationStatus.notDetermined;
    await manager.setEnabled(true);
    expect(messaging.requestCount, 1);
    expect(manager.isAuthorized, isFalse);

    messaging.status = AuthorizationStatus.authorized;
    await manager.setEnabled(true);
    expect(manager.isAuthorized, isTrue);
    expect(api.upserts, 1);
  });

  test('setEnabled(false) opens settings', () async {
    messaging.status = AuthorizationStatus.authorized;
    await manager.refreshAuthorization();

    await manager.setEnabled(false);

    expect(messaging.openSettingsCount, 1);
    expect(manager.isAuthorized, isTrue);
  });

  test('refresh unregisters token after authorization is revoked', () async {
    messaging.status = AuthorizationStatus.authorized;
    await manager.refreshAuthorization();
    expect(api.upserts, 1);

    messaging.status = AuthorizationStatus.denied;
    await manager.refreshAuthorization();
    expect(api.deletes, 1);
    expect(manager.isAuthorized, isFalse);
  });
}
