import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:gostylens/core/config/dependency_injection.dart';
import 'package:gostylens/core/services/api_service/index.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) {
    print("Handling background message: ${message.messageId}");
  }
}

class PushNotificationManager {
  final PushNotificationApiService _apiService;
  bool _initialized = false;
  String? _currentToken;

  PushNotificationManager() : _apiService = locator<PushNotificationApiService>();

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      final messaging = FirebaseMessaging.instance;

      // Request permissions
      final settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (kDebugMode) {
        print('User granted permission: ${settings.authorizationStatus}');
      }

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        // Register token
        final token = await messaging.getToken();
        if (token != null) {
          await _registerToken(token);
        }

        // Handle token refresh
        messaging.onTokenRefresh.listen((newToken) {
          _registerToken(newToken);
        });

        // Set background message handler
        FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

        // Foreground messages listener
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          if (kDebugMode) {
            print('Got a message in the foreground!');
            print('Message data: ${message.data}');
            if (message.notification != null) {
              print('Message also contained a notification: ${message.notification?.title}');
            }
          }
        });

        _initialized = true;
      }
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
