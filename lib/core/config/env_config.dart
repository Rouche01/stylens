import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConfig {
  static String get supabaseUrl => _get('SUPABASE_URL');
  static String get supabaseAnonKey => _get('SUPABASE_ANON_KEY');
  static String get apiBaseUrl => _get('API_BASE_URL');

  static String get revenueCatApiKey {
    if (kIsWeb) return '';
    if (Platform.isIOS) return _get('IOS_REVENUE_CAT_API_KEY');
    if (Platform.isAndroid) return _get('ANDROID_REVENUE_CAT_API_KEY');
    return '';
  }

  static String get googleOAuthClientId {
    if (kIsWeb) return googleOAuthWebClientId;
    if (Platform.isIOS) return googleOAuthIosClientId;
    if (Platform.isAndroid) return googleOAuthAndroidClientId;
    return googleOAuthWebClientId;
  }

  static String get googleOAuthWebClientId =>
      _get('GOOGLE_OAUTH_WEB_CLIENT_ID');
  static String get googleOAuthIosClientId =>
      _get('GOOGLE_OAUTH_IOS_CLIENT_ID');
  static String get googleOAuthAndroidClientId =>
      _get('GOOGLE_OAUTH_ANDROID_CLIENT_ID');
  static String get posthogApiKey => _get('POSTHOG_API_KEY');
  static String get posthogHost => _get('POSTHOG_HOST');

  /// Call this on app startup to ensure all required environment variables are present.
  static void init() {
    supabaseUrl;
    supabaseAnonKey;
    apiBaseUrl;

    // Validate platform-specific RevenueCat keys
    if (!kIsWeb) {
      _get('IOS_REVENUE_CAT_API_KEY');
      _get('ANDROID_REVENUE_CAT_API_KEY');
    }

    googleOAuthWebClientId;
    googleOAuthIosClientId;
    googleOAuthAndroidClientId;
    posthogApiKey;
    posthogHost;
  }

  static String _get(String key) {
    final value = dotenv.env[key];
    if (value == null || value.isEmpty) {
      throw Exception('Environment variable $key is missing or empty.');
    }
    return value.trim();
  }
}
