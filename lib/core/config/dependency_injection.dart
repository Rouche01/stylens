import 'dart:io';

import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart' as dio;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:gostylens/core/config/env_config.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gostylens/core/managers/global_loader/global_loader_controller.dart';
import 'package:gostylens/core/services/api_service/auth_interceptor.dart';
import 'package:gostylens/core/services/api_service/user_api_service.dart';
import 'package:gostylens/core/services/api_service/asset_api_service.dart';
import 'package:gostylens/core/services/api_service/subscription_api_service.dart';
import 'package:gostylens/core/services/api_service/style_analysis_api_service.dart';

import 'package:gostylens/core/managers/auth_state_manager.dart';
import 'package:gostylens/core/managers/subscription_manager.dart';
import 'package:gostylens/core/managers/style_analysis_session/index.dart';
import 'package:gostylens/core/managers/user_state_manager.dart';
import 'package:gostylens/core/services/analytics_service.dart';
import 'package:gostylens/core/managers/asset_upload_manager.dart';

// Global locator instance
final locator = GetIt.instance;

/// Sets up the service locator for dependency injection.
/// This should be called once during app initialization.
Future<void> setupLocator() async {
  // Initialize Supabase
  await Supabase.initialize(
    url: EnvConfig.supabaseUrl,
    anonKey: EnvConfig.supabaseAnonKey,
  );

  // Initialize Google Sign In
  final String? googleClientId = Platform.isIOS
      ? EnvConfig.googleOAuthIosClientId
      : null;

  await GoogleSignIn.instance.initialize(
    clientId: googleClientId,
    serverClientId: EnvConfig.googleOAuthWebClientId,
  );

  // Register Analytics Service
  final analyticsService = AnalyticsService();
  await analyticsService.init();
  locator.registerSingleton<AnalyticsService>(analyticsService);

  // Register API Services as Lazy Singletons
  // Lazy means they won't be instantiated until the first time they are requested.
  locator.registerLazySingleton<UserApiService>(() => UserApiService());
  locator.registerLazySingleton<AssetApiService>(() => AssetApiService());
  locator.registerLazySingleton<SubscriptionApiService>(
    () => SubscriptionApiService(),
  );
  locator.registerLazySingleton<StyleAnalysisApiService>(
    () => StyleAnalysisApiService(),
  );

  // Setup Singletons
  locator.registerLazySingleton<SupabaseClient>(() => Supabase.instance.client);
  locator.registerLazySingleton<GlobalLoaderController>(
    () => GlobalLoaderController(),
  );

  // Setup Dio
  locator.registerLazySingleton<dio.Dio>(() {
    final d = dio.Dio(
      dio.BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    d.interceptors.add(SupabaseAuthInterceptor(d));

    if (kDebugMode) {
      d.interceptors.add(
        PrettyDioLogger(
          requestHeader: true,
          requestBody: true,
          responseBody: true,
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
}
