import 'dart:async';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:gostylens/core/config/env_config.dart';
import 'package:gostylens/core/config/feature_flags.dart';
import 'package:gostylens/core/services/feature_flag_service.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

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
  bool _attRequestInFlight = false;
  /// Profile is ready — we want ATT/start, but may still be on splash.
  bool _attArmed = false;
  /// Past splash / on a real screen ([AuthStage.userReady]).
  bool _attUiReady = false;
  /// Events logged before [AppsFlyerSdk.start] (e.g. registration at signup).
  final List<AppsFlyerEvent> _pendingAppsFlyerEvents = [];

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
  ///
  /// Queues until after [AppsFlyerSdk.start] so signup registration is not
  /// dropped while ATT delays the first session.
  Future<void> logAppsFlyerEvent(AppsFlyerEvent event) async {
    if (!_appsFlyerSupported) return;
    if (!_appsFlyerStarted) {
      _pendingAppsFlyerEvents.add(event);
      return;
    }
    await _sendAppsFlyerEvent(event);
  }

  Future<void> _sendAppsFlyerEvent(AppsFlyerEvent event) async {
    try {
      await AppsFlyerSdk.instance.logEvent(event.wireName);
    } catch (e) {
      debugPrint('Failed to log AppsFlyer event ${event.wireName}: $e');
    }
  }

  Future<void> _flushPendingAppsFlyerEvents() async {
    if (_pendingAppsFlyerEvents.isEmpty) return;
    final pending = List<AppsFlyerEvent>.of(_pendingAppsFlyerEvents);
    _pendingAppsFlyerEvents.clear();
    for (final event in pending) {
      await _sendAppsFlyerEvent(event);
    }
  }

  /// Arm ATT / AppsFlyer start once the profile is ready (fetch or create).
  ///
  /// Does not show the system dialog until [markAppInteractiveForTracking]
  /// (after splash → [AuthStage.userReady]). Idempotent.
  void requestTrackingAndStartAppsFlyerIfNeeded() {
    if (!_appsFlyerSupported) return;
    _attArmed = true;
    unawaited(_flushTrackingAndStartIfReady());
  }

  /// Call when the UI is past splash and the user can see a real screen.
  void markAppInteractiveForTracking() {
    if (!_appsFlyerSupported) return;
    _attUiReady = true;
    unawaited(_flushTrackingAndStartIfReady());
  }

  Future<void> _flushTrackingAndStartIfReady() async {
    if (!_attArmed || !_attUiReady) return;
    if (_attRequestInFlight) return;
    _attRequestInFlight = true;
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final status =
            await AppTrackingTransparency.trackingAuthorizationStatus;
        if (status == TrackingStatus.notDetermined) {
          // Wait for the home route to paint; ATT fails silently on splash.
          await Future<void>.delayed(const Duration(milliseconds: 600));
          await AppTrackingTransparency.requestTrackingAuthorization();
        }
      }
      await _startAppsFlyer();
    } catch (e) {
      debugPrint('Failed ATT / AppsFlyer start: $e');
    } finally {
      _attRequestInFlight = false;
    }
  }

  Future<void> _startAppsFlyer() async {
    if (_appsFlyerStarted || !_appsFlyerSessionReady) return;
    _appsFlyerStarted = true;
    await AppsFlyerSdk.instance.start();
    await _flushPendingAppsFlyerEvents();
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
    final enriched = _propertiesWithFeatureFlags(properties);
    if (kDebugMode) {
      debugPrint('📊 [PostHog] Event: $eventName');
      if (enriched != null) debugPrint('   Properties: $enriched');
    }
    if (!isEnabled) return;
    await Posthog().capture(eventName: eventName, properties: enriched);
  }

  /// Stamps `$feature/<key>` from the API flag snapshot. Caller props win.
  /// Skips when [FeatureFlagService] has no snapshot yet.
  Map<String, Object>? _propertiesWithFeatureFlags(
    Map<String, Object>? properties,
  ) {
    final getIt = GetIt.instance;
    if (!getIt.isRegistered<FeatureFlagService>()) return properties;
    final flags = getIt<FeatureFlagService>();
    if (!flags.hasSnapshot) return properties;

    final snapshot = flags.snapshot!;
    final merged = <String, Object>{
      for (final key in FeatureFlags.keys)
        '\$feature/$key': snapshot[key] ?? false,
    };
    if (properties != null) merged.addAll(properties);
    return merged;
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
