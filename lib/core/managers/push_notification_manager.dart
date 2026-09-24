import 'dart:async';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:gostylens/core/config/dependency_injection.dart';
import 'package:gostylens/core/managers/foreground_notification_handler.dart';
import 'package:gostylens/core/managers/push_messaging.dart';
import 'package:gostylens/core/navigation/deep_link/deep_link_service.dart';
import 'package:gostylens/core/services/analytics_service.dart';
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

class PushNotificationManager extends ChangeNotifier {
  PushNotificationManager({
    ForegroundNotificationHandler? foregroundHandler,
    PushNotificationApiService? apiService,
    PushMessaging? messaging,
    Future<String?> Function()? resolveTimezone,
    AnalyticsService? analytics,
  }) : _apiServiceOverride = apiService,
       _foregroundHandlerOverride = foregroundHandler,
       _messaging = messaging ?? PushMessaging(),
       _resolveTimezone = resolveTimezone ?? _defaultResolveTimezone,
       _analyticsOverride = analytics;

  final PushNotificationApiService? _apiServiceOverride;
  final ForegroundNotificationHandler? _foregroundHandlerOverride;
  final PushMessaging _messaging;
  final Future<String?> Function() _resolveTimezone;
  final AnalyticsService? _analyticsOverride;

  PushNotificationApiService get _apiService =>
      _apiServiceOverride ?? locator<PushNotificationApiService>();

  ForegroundNotificationHandler get _foregroundHandler =>
      _foregroundHandlerOverride ?? locator<ForegroundNotificationHandler>();

  AnalyticsService get _analytics =>
      _analyticsOverride ?? locator<AnalyticsService>();

  bool _permissionRequested = false;
  bool _notificationsAuthorized = false;
  String? _currentToken;
  String? _registeredTimezone;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedAppSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;
  bool _initialMessageHandled = false;

  bool get isAuthorized => _notificationsAuthorized;

  static bool isGranted(AuthorizationStatus status) =>
      status == AuthorizationStatus.authorized ||
      status == AuthorizationStatus.provisional;

  static Future<String?> _defaultResolveTimezone() async {
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      final id = info.identifier.trim();
      return id.isEmpty ? null : id;
    } catch (e) {
      if (kDebugMode) {
        print('Failed to resolve local timezone: $e');
      }
      return null;
    }
  }

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

  /// Handles notification taps when the app was backgrounded or killed.
  void attachOpenedAppListener() {
    _openedAppSubscription ??=
        // backgrounded (warm resume)
        FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedAppMessage);

    if (_initialMessageHandled) return;
    _initialMessageHandled = true;

    // killed (cold start)
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        _handleOpenedAppMessage(message);
      }
    });
  }

  void _handleOpenedAppMessage(RemoteMessage message) {
    if (kDebugMode) {
      print('Notification opened app: ${message.data}');
    }
    final type = message.data['type'] ?? message.data['notification_type'];
    unawaited(
      _analytics.capture(
        'notification_opened',
        properties: {
          if (type != null) 'type': type.toString(),
          if (message.messageId != null) 'message_id': message.messageId!,
        },
      ),
    );
    locator<DeepLinkService>().handlePushData(message.data);
  }

  Future<void> initialize() async {
    attachForegroundListener();

    try {
      if (!_permissionRequested) {
        final status = await _messaging.requestPermission();
        _permissionRequested = true;
        _setAuthorized(isGranted(status));
        if (kDebugMode) {
          print('User granted permission: $status');
        }
      }

      await refreshAuthorization();
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing push notifications: $e');
      }
    }
  }

  /// Re-reads OS authorization. Unregisters the FCM token when unauthorized.
  Future<void> refreshAuthorization() async {
    try {
      final status = await _messaging.authorizationStatus();
      _setAuthorized(isGranted(status));
      if (!_notificationsAuthorized) {
        await unregisterToken();
        return;
      }

      await _messaging.configureForegroundPresentation();
      final token = await _messaging.getToken();
      if (token != null) {
        await _registerToken(token);
      }
      _tokenRefreshSubscription ??= _messaging.onTokenRefresh.listen(
        _registerToken,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error refreshing push authorization: $e');
      }
    }
  }

  /// Turns notifications on or off via OS permission.
  ///
  /// On: request permission, or open Settings if already denied.
  /// Off: open Settings (the app cannot revoke OS permission).
  Future<void> setEnabled(bool value) async {
    if (value) {
      final status = await _messaging.authorizationStatus();
      if (status == AuthorizationStatus.denied) {
        await _messaging.openAppNotificationSettings();
        return;
      }
      if (!isGranted(status)) {
        final next = await _messaging.requestPermission();
        _permissionRequested = true;
        _setAuthorized(isGranted(next));
        if (!_notificationsAuthorized) return;
      }
      await refreshAuthorization();
      return;
    }

    await _messaging.openAppNotificationSettings();
  }

  void _setAuthorized(bool authorized) {
    if (_notificationsAuthorized == authorized) return;
    _notificationsAuthorized = authorized;
    notifyListeners();
  }

  Future<void> _registerToken(String token) async {
    if (!_notificationsAuthorized) return;

    final timezone = await _resolveTimezone();
    if (_currentToken == token && _registeredTimezone == timezone) return;

    try {
      final platform = Platform.isIOS ? 'ios' : 'android';
      final response = await _apiService.upsertToken(
        token: token,
        platform: platform,
        timezone: timezone,
      );

      if (response.isSuccess) {
        _currentToken = token;
        _registeredTimezone = timezone;
        if (kDebugMode) {
          print('Push token successfully registered: $token (tz=$timezone)');
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
    final tokenToDelete = _currentToken ?? await _messaging.getToken();
    if (tokenToDelete == null) return;

    try {
      final response = await _apiService.deleteToken(tokenToDelete);
      if (response.isSuccess) {
        if (kDebugMode) {
          print('Push token successfully deleted from backend');
        }
        _currentToken = null;
        _registeredTimezone = null;
      } else {
        if (kDebugMode) {
          print(
            'Failed to delete push token from backend: ${response.error?.message}',
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error unregistering push token: $e');
      }
    }
  }
}
