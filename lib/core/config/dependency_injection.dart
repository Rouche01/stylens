import 'dart:io';

import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart' as dio;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:gostylens/core/config/env_config.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:dio_cache_interceptor_hive_store/dio_cache_interceptor_hive_store.dart';

import 'package:gostylens/core/managers/global_loader/global_loader_controller.dart';
import 'package:gostylens/core/services/api_service/auth_interceptor.dart';
import 'package:gostylens/core/services/api_service/user_api_service.dart';
import 'package:gostylens/core/services/api_service/asset_api_service.dart';
import 'package:gostylens/core/services/api_service/subscription_api_service.dart';
import 'package:gostylens/core/services/api_service/style_analysis_api_service.dart';
import 'package:gostylens/core/services/api_service/push_notification_api_service.dart';
import 'package:gostylens/core/services/api_service/config_api_service.dart';

import 'package:gostylens/core/managers/auth_state_manager.dart';
import 'package:gostylens/core/managers/subscription_manager.dart';
import 'package:gostylens/core/managers/style_analysis_session/index.dart';
import 'package:gostylens/core/managers/user_state_manager.dart';
import 'package:gostylens/core/services/analytics_service.dart';
import 'package:gostylens/core/services/feature_flag_service.dart';
import 'package:gostylens/core/services/pose_video_service.dart';
import 'package:gostylens/core/managers/asset_upload_manager.dart';
import 'package:gostylens/core/managers/foreground_notification_handler.dart';
import 'package:gostylens/core/services/realtime_service.dart';
import 'package:gostylens/core/managers/push_notification_manager.dart';
import 'package:gostylens/core/managers/location_manager.dart';
import 'package:gostylens/core/managers/stylist_openers_manager.dart';
import 'package:gostylens/core/managers/invite_code_store.dart';
import 'package:gostylens/core/managers/intro_walkthrough_store.dart';
import 'package:gostylens/core/navigation/deep_link/deep_link_parser.dart';
import 'package:gostylens/core/navigation/deep_link/deep_link_router.dart';
import 'package:gostylens/core/navigation/deep_link/deep_link_service.dart';

// Global locator instance
final locator = GetIt.instance;

/// Sets up the service locator for dependency injection.
/// This should be called once during app initialization.
Future<void> setupLocator() async {
  // Initialize Supabase
  await Supabase.initialize(
    url: EnvConfig.supabaseUrl,
    publishableKey: EnvConfig.supabaseAnonKey,
  );

  // Initialize Google Sign In (must not block app launch forever on Play builds).
  final String? googleClientId = Platform.isIOS
      ? EnvConfig.googleOAuthIosClientId
      : null;

  try {
    await GoogleSignIn.instance
        .initialize(
          clientId: googleClientId,
          serverClientId: EnvConfig.googleOAuthWebClientId,
        )
        .timeout(const Duration(seconds: 8));
  } catch (e, st) {
    debugPrint('GoogleSignIn.initialize failed/timed out: $e\n$st');
  }

  // Register Analytics Service — PostHog network setup must not gate first frame.
  final analyticsService = AnalyticsService();
  await analyticsService.init().timeout(
    const Duration(seconds: 8),
    onTimeout: () {
      debugPrint('AnalyticsService.init timed out; continuing without PostHog');
    },
  );
  locator.registerSingleton<AnalyticsService>(analyticsService);
  locator.registerSingleton<FeatureFlagService>(
    FeatureFlagService(analyticsService),
  );
  locator.registerLazySingleton<PoseVideoService>(() => PoseVideoService());

  // Initialize Hybrid Cache Store for Dio (Memory + Hive)
  final cacheDir = await getApplicationDocumentsDirectory();
  final diskStore = HiveCacheStore(
    cacheDir.path,
    hiveBoxName: 'stylens_api_cache',
  );
  final memStore = MemCacheStore();

  final cacheStore = BackupCacheStore(primary: memStore, secondary: diskStore);

  final cacheOptions = CacheOptions(
    store: cacheStore,
    policy:
        CachePolicy.request, // strictly adhere to HTTP Cache-Control headers
    hitCacheOnErrorExcept: [
      401,
      403,
    ], // fallback to cache on network errors Except Auth errors
    maxStale: const Duration(days: 7),
    priority: CachePriority.normal,
    cipher: null,
    keyBuilder: CacheOptions.defaultCacheKeyBuilder,
    allowPostMethod: false,
  );

  // Register API Services as Lazy Singletons
  locator.registerLazySingleton<UserApiService>(() => UserApiService());
  locator.registerLazySingleton<AssetApiService>(() => AssetApiService());
  locator.registerLazySingleton<SubscriptionApiService>(
    () => SubscriptionApiService(),
  );
  locator.registerLazySingleton<StyleAnalysisApiService>(
    () => StyleAnalysisApiService(),
  );
  locator.registerLazySingleton<PushNotificationApiService>(
    () => PushNotificationApiService(),
  );
  locator.registerLazySingleton<ConfigApiService>(() => ConfigApiService());

  // Setup Singletons
  final supabaseClient = Supabase.instance.client;
  locator.registerLazySingleton<SupabaseClient>(() => supabaseClient);
  locator.registerLazySingleton<RealtimeService>(
    () => RealtimeService(supabaseClient),
  );
  locator.registerLazySingleton<GlobalLoaderController>(
    () => GlobalLoaderController(),
  );
  locator.registerLazySingleton<ForegroundNotificationHandler>(
    () => ForegroundNotificationHandler(),
  );
  locator.registerLazySingleton<DeepLinkParser>(() => DeepLinkParser());
  locator.registerLazySingleton<DeepLinkRouter>(() => DeepLinkRouter());
  locator.registerLazySingleton<DeepLinkService>(
    () => DeepLinkService(
      parser: locator<DeepLinkParser>(),
      router: locator<DeepLinkRouter>(),
    ),
  );

  // Setup Dio
  locator.registerLazySingleton<dio.Dio>(() {
    final d = dio.Dio(
      dio.BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        validateStatus: (status) =>
            status != null &&
            ((status >= 200 && status < 300) || status == 304),
      ),
    );

    d.interceptors.add(SupabaseAuthInterceptor(d));
    d.interceptors.add(DioCacheInterceptor(options: cacheOptions));

    if (kDebugMode) {
      d.interceptors.add(
        PrettyDioLogger(
          requestHeader: true,
          requestBody: true,
          responseBody: false, // Disable global body logging for performance
          responseHeader: false,
          error: true,
          compact: true,
          maxWidth: 90,
        ),
      );
    }

    return d;
  });

  // Setup Google Sign In
  locator.registerLazySingleton<GoogleSignIn>(() => GoogleSignIn.instance);

  // Register Managers as Lazy Singletons
  locator.registerLazySingleton<SubscriptionManager>(
    () => SubscriptionManager(),
  );
  locator.registerLazySingleton<AuthStateManager>(() => AuthStateManager());
  locator.registerLazySingleton<StyleAnalysisSessionManager>(
    () => StyleAnalysisSessionManager(),
  );
  locator.registerLazySingleton<UserStateManager>(() => UserStateManager());
  locator.registerLazySingleton<AssetUploadManager>(() => AssetUploadManager());
  locator.registerLazySingleton<PushNotificationManager>(
    () => PushNotificationManager(),
  );
  locator.registerLazySingleton<LocationManager>(() => LocationManager());
  locator.registerLazySingleton<InviteCodeStore>(() => InviteCodeStore());
  final introStore = IntroWalkthroughStore();
  await introStore.warm();
  locator.registerSingleton<IntroWalkthroughStore>(introStore);
  locator.registerLazySingleton<StylistOpenersManager>(
    () => StylistOpenersManager(),
  );
}
