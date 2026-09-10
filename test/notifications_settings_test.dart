import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostylens/core/managers/push_messaging.dart';
import 'package:gostylens/core/managers/push_notification_manager.dart';
import 'package:gostylens/core/managers/user_state_manager.dart';
import 'package:gostylens/core/services/api_service/push_notification_api_service.dart';
import 'package:gostylens/core/services/api_service/user_api_service.dart';
import 'package:gostylens/models/api_responses/api_response.dart';
import 'package:gostylens/models/api_responses/email_prefs.dart';
import 'package:gostylens/pages/notifications_settings.dart';
import 'package:provider/provider.dart';

class _FakeUserApiService extends UserApiService {
  @override
  Future<ApiResponse<EmailPrefs>> getEmailPrefs() async {
    return ApiResponse.success(EmailPrefs.optedOut);
  }
}

class _FakePushMessaging extends PushMessaging {
  @override
  Future<AuthorizationStatus> authorizationStatus() async =>
      AuthorizationStatus.authorized;

  @override
  Future<AuthorizationStatus> requestPermission() async =>
      AuthorizationStatus.authorized;

  @override
  Future<String?> getToken() async => 'tok';

  @override
  Stream<String> get onTokenRefresh => const Stream.empty();

  @override
  Future<void> configureForegroundPresentation() async {}

  @override
  Future<bool> openAppNotificationSettings() async => true;
}

class _FakePushApi extends PushNotificationApiService {
  @override
  Future<ApiResponse<void>> upsertToken({
    required String token,
    required String platform,
  }) async {
    return ApiResponse.success(null);
  }

  @override
  Future<ApiResponse<void>> deleteToken(String token) async {
    return ApiResponse.success(null);
  }
}

void main() {
  testWidgets('shows in-app and email toggles', (tester) async {
    final push = PushNotificationManager(
      apiService: _FakePushApi(),
      messaging: _FakePushMessaging(),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => UserStateManager(userApiService: _FakeUserApiService()),
        child: MaterialApp(
          home: NotificationsSettingsPage(pushNotifications: push),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Notifications'), findsWidgets);
    expect(find.text('In-app notifications'), findsOneWidget);
    expect(find.text('Email tips'), findsOneWidget);
    expect(find.byType(Switch), findsNWidgets(2));

    final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
    expect(switches[0].value, isTrue);
    expect(switches[1].value, isFalse);
  });
}
