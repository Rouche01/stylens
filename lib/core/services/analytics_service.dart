import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:gostylens/core/config/env_config.dart';
import 'package:flutter/foundation.dart';

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  /// Set this to false to temporarily disable all PostHog events
  static const bool _enabled = false;

  /// Initialize PostHog with configuration
  Future<void> init() async {
    if (!_enabled) return;
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

  /// Identify a user with optional properties
  Future<void> identify(
    String userId, {
    Map<String, Object>? properties,
  }) async {
    if (kDebugMode) {
      debugPrint('👤 [PostHog] Identify: $userId');
      if (properties != null) debugPrint('   Properties: $properties');
    }
    if (!_enabled || kDebugMode) return;
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
    if (!_enabled || kDebugMode) return;
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
    if (!_enabled || kDebugMode) return;
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
    if (!_enabled || kDebugMode) return;
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
    if (!_enabled || kDebugMode) return;
    await Posthog().reset();
  }
}
