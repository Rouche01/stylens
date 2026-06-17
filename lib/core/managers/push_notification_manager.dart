import 'dart:async';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:gostylens/core/config/dependency_injection.dart';
import 'package:gostylens/core/managers/foreground_notification_handler.dart';
import 'package:gostylens/core/services/api_service/index.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) {
    print("Handling background message: ${message.messageId}");
  }
}

/// Registers the background handler. Must run before [runApp].
void registerFirebaseMessagingBackgroundHandler() {
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
}

class PushNotificationManager {
  final PushNotificationApiService _apiService;
  final ForegroundNotificationHandler _foregroundHandler;
  bool _permissionRequested = false;
  bool _notificationsAuthorized = false;
  String? _currentToken;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;

  PushNotificationManager({
    ForegroundNotificationHandler? foregroundHandler,
  })  : _apiService = locator<PushNotificationApiService>(),
        _foregroundHandler =
            foregroundHandler ?? locator<ForegroundNotificationHandler>();

  /// Attaches the foreground listener once. Safe to call from [main].
  void attachForegroundListener() {
    _foregroundSubscription ??= FirebaseMessaging.onMessage.listen(
      _foregroundHandler.handle,
      onError: (Object error, StackTrace stackTrace) {
        if (kDebugMode) {
          print('FirebaseMessaging.onMessage error: $error');
        }
      },
    );
  }

  Future<void> initialize() async {
    attachForegroundListener();

    try {
      final messaging = FirebaseMessaging.instance;

      if (!_permissionRequested) {
        final settings = await messaging.requestPermission(
          alert: true,
          announcement: false,
          badge: true,
          carPlay: false,
          criticalAlert: false,
          provisional: false,
          sound: true,
        );

        _permissionRequested = true;
        _notificationsAuthorized =
            settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;

        if (kDebugMode) {
          print('User granted permission: ${settings.authorizationStatus}');
        }
      }

      if (!_notificationsAuthorized) return;

      // Use in-app snackbars in foreground instead of the system banner.
      await messaging.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: true,
        sound: false,
      );

      final token = await messaging.getToken();
      if (token != null) {
        await _registerToken(token);
      }

      _tokenRefreshSubscription ??=
          messaging.onTokenRefresh.listen(_registerToken);
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing push notifications: $e');
      }
    }
  }

  Future<void> _registerToken(String token) async {
    if (_currentToken == token) return;

    try {
      final platform = Platform.isIOS ? 'ios' : 'android';
      final response = await _apiService.upsertToken(
        token: token,
        platform: platform,
      );

      if (response.isSuccess) {
        _currentToken = token;
        if (kDebugMode) {
          print('Push token successfully registered: $token');
        }
      } else {
        if (kDebugMode) {
          print('Failed to register push token: ${response.error?.message}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error calling upsertToken: $e');
      }
    }
  }

  Future<void> unregisterToken() async {
    final tokenToDelete = _currentToken ?? await FirebaseMessaging.instance.getToken();
    if (tokenToDelete == null) return;

    try {
      final response = await _apiService.deleteToken(tokenToDelete);
      if (response.isSuccess) {
        if (kDebugMode) {
          print('Push token successfully deleted from backend');
        }
        _currentToken = null;
      } else {
        if (kDebugMode) {
          print('Failed to delete push token from backend: ${response.error?.message}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error unregistering push token: $e');
      }
    }
  }
}
