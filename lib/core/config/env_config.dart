import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConfig {
  static String get supabaseUrl => _get('SUPABASE_URL');
  static String get supabaseAnonKey => _get('SUPABASE_ANON_KEY');
  static String get apiBaseUrl => _get('API_BASE_URL');
  static String get revenueCatApiKey => _get('REVENUE_CAT_API_KEY');

  static String _get(String key) {
    final value = dotenv.env[key];
    if (value == null || value.isEmpty) {
      throw Exception('Environment variable $key is missing or empty.');
    }
    return value;
  }
}
