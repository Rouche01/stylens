import 'dart:async';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:gostylens/core/config/env_config.dart';
import 'package:gostylens/core/config/feature_flags.dart';
import 'package:gostylens/core/prefs/local_prefs_service.dart';
import 'package:gostylens/core/services/appsflyer_attribution_sync.dart';
import 'package:gostylens/core/services/att_prompt_policy.dart';
import 'package:gostylens/core/services/feature_flag_service.dart';
import 'package:gostylens/core/services/pending_appsflyer_events.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

/// Closed list of AppsFlyer events this app sends. Purchases stay on RevenueCat.
enum AppsFlyerEvent {
  registration('af_complete_registration'),
  activation('af_activation');

  const AppsFlyerEvent(this.wireName);
  final String wireName;

  static AppsFlyerEvent? byWireName(String name) {
    for (final event in values) {
      if (event.wireName == name) return event;
    }
    return null;
  }
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
  /// Disk-backed events logged before AppsFlyer start (registration at signup).
  PendingAppsFlyerEventQueue? _pendingAppsFlyerEvents;
  final AttPromptMachine _attPrompt = AttPromptMachine();
  Timer? _captureRetryTimer;
  _AttResumeObserver? _attResumeObserver;
  bool _startWhenSessionReady = false;
  String _pendingStartReason = 'start';

  static bool get isEnabled => _enabled && !kDebugMode;

  /// AppsFlyer network traffic is release/profile only (same as PostHog).
  /// Debug installs must not pollute the AppsFlyer dashboard.
  static bool get appsFlyerEnabled => !kDebugMode;

  /// Initialize PostHog and AppsFlyer.
  ///
  /// Both stay off in debug. Use a profile/release build to verify attribution.
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
    if (!appsFlyerEnabled || !_appsFlyerSupported) return;
    try {
      final sdk = AppsFlyerSdk.instance;
      await sdk.enableDebug(false);
      await sdk.init(
        devKey: EnvConfig.appsFlyerDevKey,
        appId: defaultTargetPlatform == TargetPlatform.iOS
            ? EnvConfig.appsFlyerIosAppId
            : null,
      );
      await sdk.registerSessionReadyListener(() async {
        _appsFlyerSessionReady = true;
        if (defaultTargetPlatform == TargetPlatform.iOS) {
          final status =
              await AppTrackingTransparency.trackingAuthorizationStatus;
          if (status == TrackingStatus.notDetermined &&
              !_startWhenSessionReady) {
            return;
          }
        } else if ((!_attArmed || !_attUiReady) && !_startWhenSessionReady) {
          return;
        }
        await _startAppsFlyer(
          reason: _startWhenSessionReady ? _pendingStartReason : 'session_ready',
        );
      });
      debugPrint('AppsFlyer initialized');
    } catch (e, st) {
      await _reportAppsFlyerFailure('init', e, st);
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
  /// Events logged before AppsFlyer start are written to local prefs first, so
  /// a quit during the tracking prompt still sends them on the next launch.
  Future<void> logAppsFlyerEvent(AppsFlyerEvent event) async {
    if (!appsFlyerEnabled || !_appsFlyerSupported) return;
    // Temporary TestFlight check. Remove with the other appsflyer_diag captures.
    await _diagAppsFlyer('triggered', {
      'wire_name': event.wireName,
      'sdk_started': _appsFlyerStarted,
    });
    final queue = _pendingQueue();
    if (!_appsFlyerStarted) {
      if (queue == null) {
        await _diagAppsFlyer('queued', {
          'wire_name': event.wireName,
          'queue_ready': false,
        });
        return;
      }
      await queue.enqueue(event.wireName);
      await _diagAppsFlyer('queued', {
        'wire_name': event.wireName,
        'queue_ready': true,
        'pending': queue.wireNames.join(','),
      });
      return;
    }
    final sent = await _sendAppsFlyerEvent(event);
    if (!sent) {
      await queue?.enqueue(event.wireName);
      await _diagAppsFlyer('queued', {
        'wire_name': event.wireName,
        'queue_ready': queue != null,
        'pending': queue?.wireNames.join(',') ?? '',
        'after_send_failure': true,
      });
    }
  }

  /// Returns false when the SDK rejected the event so the caller can keep it.
  Future<bool> _sendAppsFlyerEvent(AppsFlyerEvent event) async {
    try {
      await AppsFlyerSdk.instance.logEvent(event.wireName);
      return true;
    } catch (e, st) {
      await _reportAppsFlyerFailure('log_event:${event.wireName}', e, st);
      return false;
    }
  }

  Future<void> _flushPendingAppsFlyerEvents({String reason = 'start'}) async {
    final queue = _pendingQueue();
    await _diagAppsFlyer('flush', {
      'reason': reason,
      'queue_ready': queue != null,
      'pending': queue?.wireNames.join(',') ?? '',
    });
    if (queue == null) return;
    while (queue.wireNames.isNotEmpty) {
      final event = AppsFlyerEvent.byWireName(queue.wireNames.first);
      if (event == null) {
        await queue.acknowledgeFirst();
        continue;
      }
      final sent = await _sendAppsFlyerEvent(event);
      if (!sent) return;
      await queue.acknowledgeFirst();
    }
  }

  /// Null until [LocalPrefsService] is registered (after [init] during bootstrap).
  PendingAppsFlyerEventQueue? _pendingQueue() {
    final existing = _pendingAppsFlyerEvents;
    if (existing != null) return existing;
    final getIt = GetIt.instance;
    if (!getIt.isRegistered<LocalPrefsService>()) return null;
    final queue = PendingAppsFlyerEventQueue(getIt<LocalPrefsService>());
    queue.load();
    _pendingAppsFlyerEvents = queue;
    return queue;
  }

  /// Arm ATT / AppsFlyer start once the profile is ready (fetch or create).
  ///
  /// Does not show the system dialog until [markAppInteractiveForTracking]
  /// (after splash → [AuthStage.userReady]). Idempotent.
  void requestTrackingAndStartAppsFlyerIfNeeded() {
    if (!appsFlyerEnabled || !_appsFlyerSupported) return;
    _attArmed = true;
    unawaited(_flushTrackingAndStartIfReady());
  }

  /// Call when the UI is past splash and the user can see a real screen.
  void markAppInteractiveForTracking() {
    if (!appsFlyerEnabled || !_appsFlyerSupported) return;
    _attUiReady = true;
    unawaited(_flushTrackingAndStartIfReady());
  }

  Future<void> _flushTrackingAndStartIfReady({
    AttTrigger trigger = AttTrigger.initial,
  }) async {
    final blocked = !_attArmed || !_attUiReady
        ? 'not_ready'
        : _attRequestInFlight
        ? 'in_flight'
        : !_attPrompt.shouldAttempt(trigger)
        ? 'attempt_blocked'
        : null;
    await _diagAppsFlyer('attempt', {
      'trigger': trigger.name,
      'armed': _attArmed,
      'ui_ready': _attUiReady,
      'skip': blocked ?? 'none',
    });
    if (blocked != null) return;
    _attRequestInFlight = true;
    try {
      final isIos = defaultTargetPlatform == TargetPlatform.iOS;
      if (!isIos) {
        _attPrompt.markStarted();
        await _startAppsFlyer(reason: trigger.name);
        return;
      }

      var status = await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status == TrackingStatus.notDetermined) {
        if (trigger == AttTrigger.initial) {
          await Future<void>.delayed(const Duration(milliseconds: 600));
        }
        await AppTrackingTransparency.requestTrackingAuthorization();
        status = await AppTrackingTransparency.trackingAuthorizationStatus;
      }
      _attPrompt.record(trigger);
      await _diagAppsFlyer('att_status', {
        'trigger': trigger.name,
        'status': status.name,
        'will_start': shouldStartAppsFlyer(isIos: true, status: status),
      });
      if (!shouldStartAppsFlyer(isIos: true, status: status)) {
        _scheduleCaptureRetry();
        if (_attPrompt.shouldObserveResume) {
          _ensureAttResumeObserver();
        } else {
          _detachAttResumeObserver();
        }
        return;
      }
      _attPrompt.markStarted();
      _cancelAttRetries();
      await _startAppsFlyer(reason: trigger.name);
    } catch (e, st) {
      await _reportAppsFlyerFailure('att_or_start', e, st);
    } finally {
      _attRequestInFlight = false;
    }
  }

  void _scheduleCaptureRetry() {
    if (!_attPrompt.shouldScheduleCaptureRetry || _captureRetryTimer != null) {
      return;
    }
    if (AttCaptureVisibility.check()) {
      _captureRetryTimer = Timer(const Duration(seconds: 2), () {
        _captureRetryTimer = null;
        unawaited(
          _flushTrackingAndStartIfReady(trigger: AttTrigger.captureSettled),
        );
      });
      return;
    }

    var polls = 0;
    _captureRetryTimer = Timer.periodic(const Duration(milliseconds: 300), (
      timer,
    ) {
      polls++;
      if (_attPrompt.started || polls > 40) {
        timer.cancel();
        _captureRetryTimer = null;
        return;
      }
      if (!AttCaptureVisibility.check()) return;
      timer.cancel();
      _captureRetryTimer = Timer(const Duration(seconds: 2), () {
        _captureRetryTimer = null;
        unawaited(
          _flushTrackingAndStartIfReady(trigger: AttTrigger.captureSettled),
        );
      });
    });
  }

  void _ensureAttResumeObserver() {
    if (!_attPrompt.shouldObserveResume || _attResumeObserver != null) return;
    final observer = _AttResumeObserver(() {
      unawaited(_flushTrackingAndStartIfReady(trigger: AttTrigger.resume));
    });
    _attResumeObserver = observer;
    WidgetsBinding.instance.addObserver(observer);
  }

  void _detachAttResumeObserver() {
    final observer = _attResumeObserver;
    if (observer == null) return;
    WidgetsBinding.instance.removeObserver(observer);
    _attResumeObserver = null;
  }

  void _cancelAttRetries() {
    _captureRetryTimer?.cancel();
    _captureRetryTimer = null;
    _detachAttResumeObserver();
  }

  Future<bool> _startAppsFlyer({String reason = 'start'}) async {
    if (_appsFlyerStarted) return true;
    if (!_appsFlyerSessionReady) {
      _startWhenSessionReady = true;
      _pendingStartReason = reason;
      return false;
    }
    try {
      _appsFlyerStarted = true;
      await AppsFlyerSdk.instance.start();
      await _flushPendingAppsFlyerEvents(reason: reason);
      await AppsFlyerAttributionSyncHook.sync?.call();
      return true;
    } catch (e, st) {
      _appsFlyerStarted = false;
      await _reportAppsFlyerFailure('start', e, st);
      return false;
    }
  }

  /// AppsFlyer install id for this device. Null off iOS and Android.
  Future<String?> appsFlyerId() async {
    if (!appsFlyerEnabled || !_appsFlyerSupported) return null;
    try {
      final id = await AppsFlyerSdk.instance.getAppsFlyerUID();
      if (id == null || id.isEmpty) return null;
      return id;
    } catch (e, st) {
      await _reportAppsFlyerFailure('get_uid', e, st);
      return null;
    }
  }

  /// Ties AppsFlyer to the same id passed to [PurchasesConfiguration.appUserID].
  Future<void> setAppsFlyerCustomerUserId(String userId) async {
    if (!appsFlyerEnabled || !_appsFlyerSupported || userId.isEmpty) return;
    try {
      await AppsFlyerSdk.instance.setCustomerUserId(userId);
    } catch (e, st) {
      await _reportAppsFlyerFailure('set_customer_user_id', e, st);
    }
  }

  bool get _appsFlyerSupported {
    if (kIsWeb) return false;
    final platform = defaultTargetPlatform;
    return platform == TargetPlatform.iOS || platform == TargetPlatform.android;
  }

  /// Real SDK failures only — not ATT-denied / ASA lookup noise in debug dumps.
  Future<void> _reportAppsFlyerFailure(
    String stage,
    Object error, [
    StackTrace? stackTrace,
  ]) async {
    debugPrint('Failed AppsFlyer $stage: $error');
    if (!isEnabled) return;
    await captureException(
      error,
      stackTrace: stackTrace,
      properties: {
        'source': 'appsflyer',
        'stage': stage,
      },
    );
  }

  /// Temporary TestFlight diagnostics for the registration queue. Remove after.
  Future<void> _diagAppsFlyer(String step, Map<String, Object> properties) {
    return capture('appsflyer_diag', properties: {'step': step, ...properties});
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

class _AttResumeObserver extends WidgetsBindingObserver {
  _AttResumeObserver(this._onResumed);

  final void Function() _onResumed;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _onResumed();
  }
}
