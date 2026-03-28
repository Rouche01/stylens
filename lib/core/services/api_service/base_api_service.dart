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
    String defaultErrorMessage = 'GET request failed',
  }) async {
    return _request<T>(
      'GET',
      path,
      fromJson: fromJson,
      defaultErrorMessage: defaultErrorMessage,
    );
  }

  Future<ApiResponse<T>> post<T>(
    String path, {
    Map<String, dynamic>? body,
    T Function(dynamic)? fromJson,
    String defaultErrorMessage = 'POST request failed',
  }) async {
    return _request<T>(
      'POST',
      path,
      data: body,
      fromJson: fromJson,
      defaultErrorMessage: defaultErrorMessage,
    );
  }

  Future<ApiResponse<T>> patch<T>(
    String path, {
    Map<String, dynamic>? body,
    T Function(dynamic)? fromJson,
    String defaultErrorMessage = 'PATCH request failed',
  }) async {
    return _request<T>(
      'PATCH',
      path,
      data: body,
      fromJson: fromJson,
      defaultErrorMessage: defaultErrorMessage,
    );
  }

  Future<ApiResponse<T>> delete<T>(
    String path, {
    String defaultErrorMessage = 'DELETE request failed',
  }) async {
    return _request<T>(
      'DELETE',
      path,
      defaultErrorMessage: defaultErrorMessage,
    );
  }

  /// Internal helper to perform a Dio request and map it to ApiResponse.
  Future<ApiResponse<T>> _request<T>(
    String method,
    String path, {
    dynamic data,
    T Function(dynamic)? fromJson,
    required String defaultErrorMessage,
  }) async {
    try {
      final response = await _dio.request(
        buildUrl(path),
        data: data,
        options: dio.Options(method: method),
      );

      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
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
