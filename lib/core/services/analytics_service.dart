import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:gostylens/core/config/env_config.dart';
import 'package:flutter/foundation.dart';

/// Closed list of AppsFlyer events this app sends. Purchases stay on RevenueCat.
enum AppsFlyerEvent {
  registration('af_complete_registration'),
  activation('af_activation');

  const AppsFlyerEvent(this.wireName);
  final String wireName;
}

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  /// Set this to false to temporarily disable all PostHog events in release.
  static const bool _enabled = true;

  bool _appsFlyerSessionReady = false;
  bool _appsFlyerStarted = false;

  static bool get isEnabled => _enabled && !kDebugMode;

  /// Initialize PostHog and AppsFlyer.
  ///
  /// PostHog stays off in debug. AppsFlyer still starts so a debug install
  /// can be verified, with SDK debug logging on.
  Future<void> init() async {
    await _initPostHog();
    await _initAppsFlyer();
  }

  Future<void> _initPostHog() async {
    if (!isEnabled) return;
    try {
      final config = PostHogConfig(EnvConfig.posthogApiKey);
      config.host = EnvConfig.posthogHost;
      config.debug = kDebugMode;
      // Product flags come from GET /config/features via FeatureFlagService.
      // Identify may still hit /flags internally; the app must not read that.
      config.preloadFeatureFlags = false;
      config.sendFeatureFlagEvents = false;

      // Enable Session Replay as requested
      config.sessionReplay = true;
      config.sessionReplayConfig = PostHogSessionReplayConfig()
        ..maskAllTexts = true
        ..maskAllImages = true;

      // Enable Error Tracking
      config.errorTrackingConfig.captureFlutterErrors = true;
      config.errorTrackingConfig.capturePlatformDispatcherErrors = true;
      config.errorTrackingConfig.captureIsolateErrors = true;
      if (defaultTargetPlatform == TargetPlatform.android) {
        config.errorTrackingConfig.captureNativeExceptions = true;
      }

      await Posthog().setup(config);
      debugPrint('PostHog initialized successfully');
    } catch (e) {
      debugPrint('Failed to initialize PostHog: $e');
    }
  }

  Future<void> _initAppsFlyer() async {
    if (kIsWeb) return;
    final platform = defaultTargetPlatform;
    if (platform != TargetPlatform.iOS && platform != TargetPlatform.android) {
      return;
    }
    try {
      final sdk = AppsFlyerSdk.instance;
      await sdk.enableDebug(kDebugMode);
      await sdk.init(
        devKey: EnvConfig.appsFlyerDevKey,
        appId: platform == TargetPlatform.iOS
            ? EnvConfig.appsFlyerIosAppId
            : null,
      );
      await sdk.registerSessionReadyListener(() async {
        _appsFlyerSessionReady = true;
        if (platform == TargetPlatform.iOS) {
          final status =
              await AppTrackingTransparency.trackingAuthorizationStatus;
          if (status == TrackingStatus.notDetermined) return;
        }
        await _startAppsFlyer();
      });
      debugPrint('AppsFlyer initialized');
    } catch (e) {
      debugPrint('Failed to initialize AppsFlyer: $e');
    }
  }

  /// Identify a user with optional properties
  Future<void> identify(
    String userId, {
    Map<String, Object>? properties,
  }) async {
    if (kDebugMode) {
      debugPrint('👤 [PostHog] Identify: $userId');
      if (properties != null) debugPrint('   Properties: $properties');
    }
    await setAppsFlyerCustomerUserId(userId);
    if (!isEnabled) return;
    await Posthog().identify(userId: userId, userProperties: properties);
  }

  /// Logs one AppsFlyer event. Installs are automatic. Purchases stay on RevenueCat.
  Future<void> logAppsFlyerEvent(AppsFlyerEvent event) async {
    if (!_appsFlyerSupported) return;
    try {
      if (event == AppsFlyerEvent.activation) {
        await _requestTrackingIfNeeded();
        await _startAppsFlyer();
      }
      await AppsFlyerSdk.instance.logEvent(event.wireName);
    } catch (e) {
      debugPrint('Failed to log AppsFlyer event ${event.wireName}: $e');
    }
  }

  /// iOS only. The system dialog appears once, after the first styling reply.
  Future<void> _requestTrackingIfNeeded() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    final status = await AppTrackingTransparency.trackingAuthorizationStatus;
    if (status != TrackingStatus.notDetermined) return;
    await AppTrackingTransparency.requestTrackingAuthorization();
  }

  Future<void> _startAppsFlyer() async {
    if (_appsFlyerStarted || !_appsFlyerSessionReady) return;
    _appsFlyerStarted = true;
    await AppsFlyerSdk.instance.start();
  }

  /// AppsFlyer install id for this device. Null off iOS and Android.
  Future<String?> appsFlyerId() async {
    if (!_appsFlyerSupported) return null;
    try {
      final id = await AppsFlyerSdk.instance.getAppsFlyerUID();
      if (id == null || id.isEmpty) return null;
      return id;
    } catch (e) {
      debugPrint('Failed to read AppsFlyer id: $e');
      return null;
    }
  }

  /// Ties AppsFlyer to the same id passed to [PurchasesConfiguration.appUserID].
  Future<void> setAppsFlyerCustomerUserId(String userId) async {
    if (!_appsFlyerSupported || userId.isEmpty) return;
    try {
      await AppsFlyerSdk.instance.setCustomerUserId(userId);
    } catch (e) {
      debugPrint('Failed to set AppsFlyer customer user id: $e');
    }
  }

  bool get _appsFlyerSupported {
    if (kIsWeb) return false;
    final platform = defaultTargetPlatform;
    return platform == TargetPlatform.iOS || platform == TargetPlatform.android;
  }

  /// Capture a custom event
  Future<void> capture(
    String eventName, {
    Map<String, Object>? properties,
  }) async {
    if (kDebugMode) {
      debugPrint('📊 [PostHog] Event: $eventName');
      if (properties != null) debugPrint('   Properties: $properties');
    }
    if (!isEnabled) return;
    await Posthog().capture(eventName: eventName, properties: properties);
  }

  /// Track a screen view
  Future<void> screen(
    String screenName, {
    Map<String, Object>? properties,
  }) async {
    if (kDebugMode) {
      debugPrint('📱 [PostHog] Screen: $screenName');
      if (properties != null) debugPrint('   Properties: $properties');
    }
    if (!isEnabled) return;
    await Posthog().screen(screenName: screenName, properties: properties);
  }

  /// Capture an exception manually
  Future<void> captureException(
    dynamic error, {
    StackTrace? stackTrace,
    Map<String, Object>? properties,
  }) async {
    if (kDebugMode) {
      debugPrint('🚨 [PostHog] Exception: $error');
      if (properties != null) debugPrint('   Properties: $properties');
    }
    if (!isEnabled) return;
    await Posthog().captureException(
      error: error,
      stackTrace: stackTrace,
      properties: properties,
    );
  }

  /// Reset the user (on logout)
  Future<void> reset() async {
    if (kDebugMode) {
      debugPrint('🔄 [PostHog] Reset');
    }
    if (!isEnabled) return;
    await Posthog().reset();
  }
}
