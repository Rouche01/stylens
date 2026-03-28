import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Interceptor that automatically attaches Supabase Auth tokens to requests
/// and handles token refreshing if a 401 Unauthorized error occurs.
class SupabaseAuthInterceptor extends QueuedInterceptor {
  final Dio dio;

  SupabaseAuthInterceptor(this.dio);

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final session = Supabase.instance.client.auth.currentSession;
    final token = session?.accessToken;

    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    return handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    const retryKey = 'is_retry';

    // If we get a 401 and it's not already a retry, attempt to refresh and retry once.
    if (err.response?.statusCode == 401 &&
        err.requestOptions.extra[retryKey] != true) {
      try {
        final response = await Supabase.instance.client.auth.refreshSession();

        if (response.session != null) {
          final newToken = response.session!.accessToken;

          // Update the failed request's header and retry
          final options = err.response!.requestOptions;
          options.headers['Authorization'] = 'Bearer $newToken';
          options.extra[retryKey] = true; // Mark as retry to avoid recursion

          // Retry the request
          final retryResponse = await dio.fetch(options);
          return handler.resolve(retryResponse);
        }
      } catch (e) {
        // If refresh fails, let the error propagate
        return handler.next(err);
      }
    }

    return handler.next(err);
  }
}
