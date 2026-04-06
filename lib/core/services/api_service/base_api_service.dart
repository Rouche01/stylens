import 'package:dio/dio.dart' as dio;
import 'package:gostylens/core/config/dependency_injection.dart';
import 'package:gostylens/core/config/env_config.dart';
import 'package:gostylens/models/api_responses/api_response.dart';

abstract class BaseApiService {
  final String resourcePath;
  String get baseUrl => EnvConfig.apiBaseUrl;

  BaseApiService({this.resourcePath = ''});

  /// Shared Dio instance from GetIt
  dio.Dio get _dio => locator<dio.Dio>();

  String buildUrl(String path) {
    // Safely combine portions, stripping out duplicate slashes but preserving 'http://'
    final rawUrl = '$baseUrl/$resourcePath/$path';
    return rawUrl.replaceAll(RegExp(r'(?<!https?:)//+'), '/');
  }

  Future<ApiResponse<T>> get<T>(
    String path, {
    T Function(dynamic)? fromJson,
    dio.Options? options,
    String defaultErrorMessage = 'GET request failed',
  }) async {
    return _request<T>(
      'GET',
      path,
      options: options,
      fromJson: fromJson,
      defaultErrorMessage: defaultErrorMessage,
    );
  }

  Future<ApiResponse<T>> post<T>(
    String path, {
    Map<String, dynamic>? body,
    T Function(dynamic)? fromJson,
    dio.Options? options,
    String defaultErrorMessage = 'POST request failed',
  }) async {
    return _request<T>(
      'POST',
      path,
      data: body,
      options: options,
      fromJson: fromJson,
      defaultErrorMessage: defaultErrorMessage,
    );
  }

  Future<ApiResponse<T>> patch<T>(
    String path, {
    Map<String, dynamic>? body,
    T Function(dynamic)? fromJson,
    dio.Options? options,
    String defaultErrorMessage = 'PATCH request failed',
  }) async {
    return _request<T>(
      'PATCH',
      path,
      data: body,
      options: options,
      fromJson: fromJson,
      defaultErrorMessage: defaultErrorMessage,
    );
  }

  Future<ApiResponse<T>> delete<T>(
    String path, {
    dio.Options? options,
    String defaultErrorMessage = 'DELETE request failed',
  }) async {
    return _request<T>(
      'DELETE',
      path,
      options: options,
      defaultErrorMessage: defaultErrorMessage,
    );
  }

  /// Internal helper to perform a Dio request and map it to ApiResponse.
  Future<ApiResponse<T>> _request<T>(
    String method,
    String path, {
    dynamic data,
    T Function(dynamic)? fromJson,
    dio.Options? options,
    required String defaultErrorMessage,
  }) async {
    try {
      final requestOptions =
          options?.copyWith(method: method) ?? dio.Options(method: method);

      final response = await _dio.request(
        buildUrl(path),
        data: data,
        options: requestOptions,
      );

      if (response.statusCode != null &&
          ((response.statusCode! >= 200 && response.statusCode! < 300) ||
              response.statusCode == 304)) {
        if (fromJson != null) {
          return ApiResponse.success(
            fromJson(response.data),
            statusCode: response.statusCode!,
          );
        }
        return ApiResponse.success(null, statusCode: response.statusCode!);
      }

      return ApiResponse.error(
        defaultMessage: defaultErrorMessage,
        dioResponse: response,
        statusCode: response.statusCode ?? -1,
      );
    } on dio.DioException catch (e) {
      return ApiResponse.error(
        defaultMessage: defaultErrorMessage,
        error: e,
        dioResponse: e.response,
      );
    } catch (e) {
      return ApiResponse.error(defaultMessage: defaultErrorMessage);
    }
  }
}
