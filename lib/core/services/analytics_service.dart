import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:gostylens/core/config/env_config.dart';
import 'package:flutter/foundation.dart';

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  /// Set this to false to temporarily disable all PostHog events in release.
  static const bool _enabled = true;

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
        await sdk.start();
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
    if (!isEnabled) return;
    await Posthog().identify(userId: userId, userProperties: properties);
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

  /// Fetches a feature flag value from PostHog.
  ///
  /// Prefer [FeatureFlagService.isEnabled] in app code — it supports local
  /// debug/profile overrides.
  Future<bool> fetchRemoteFeatureFlag(String key) async {
    if (!isEnabled) return false;
    try {
      return await Posthog().isFeatureEnabled(key);
    } catch (e) {
      debugPrint('Failed to check feature flag "$key": $e');
      return false;
    }
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
