import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:gostylens/core/config/env_config.dart';
import 'package:gostylens/models/api_responses/api_response.dart';
import 'package:gostylens/utils/api_utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

abstract class BaseApiService {
  final String resourcePath;
  String get baseUrl => EnvConfig.apiBaseUrl;

  BaseApiService({this.resourcePath = ''});

  String buildUrl(String path) {
    // Safely combine portions, stripping out duplicate slashes but preserving 'http://'
    final rawUrl = '$baseUrl/$resourcePath/$path';
    return rawUrl.replaceAll(RegExp(r'(?<!https?:)//+'), '/');
  }

  Future<Map<String, String>> get headers async {
    final session = supabase.Supabase.instance.client.auth.currentSession;
    final token = session?.accessToken;

    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<ApiResponse<T>> get<T>(
    String path, {
    T Function(dynamic)? fromJson,
    String defaultErrorMessage = 'GET request failed',
  }) async {
    try {
      final reqHeaders = await headers;
      final response = await http.get(
        Uri.parse(buildUrl(path)),
        headers: reqHeaders,
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (fromJson != null) {
          return ApiResponse<T>(
            data: fromJson(json.decode(response.body)),
            statusCode: response.statusCode,
          );
        }
        return ApiResponse<T>(statusCode: response.statusCode);
      }
      return ApiResponse<T>(
        error: parseApiError(defaultErrorMessage, response: response),
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ApiResponse<T>(
        error: parseApiError('Network error', error: e),
        statusCode: -1,
      );
    }
  }

  Future<ApiResponse<T>> post<T>(
    String path, {
    Map<String, dynamic>? body,
    T Function(dynamic)? fromJson,
    String defaultErrorMessage = 'POST request failed',
  }) async {
    try {
      final reqHeaders = await headers;
      final response = await http.post(
        Uri.parse(buildUrl(path)),
        headers: reqHeaders,
        body: body != null ? json.encode(body) : null,
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (fromJson != null) {
          return ApiResponse<T>(
            data: fromJson(json.decode(response.body)),
            statusCode: response.statusCode,
          );
        }
        return ApiResponse<T>(statusCode: response.statusCode);
      }
      return ApiResponse<T>(
        error: parseApiError(defaultErrorMessage, response: response),
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ApiResponse<T>(
        error: parseApiError('Network error', error: e),
        statusCode: -1,
      );
    }
  }

  Future<ApiResponse<T>> patch<T>(
    String path, {
    Map<String, dynamic>? body,
    T Function(dynamic)? fromJson,
    String defaultErrorMessage = 'PATCH request failed',
  }) async {
    try {
      final reqHeaders = await headers;
      final response = await http.patch(
        Uri.parse(buildUrl(path)),
        headers: reqHeaders,
        body: body != null ? json.encode(body) : null,
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (fromJson != null) {
          return ApiResponse<T>(
            data: fromJson(json.decode(response.body)),
            statusCode: response.statusCode,
          );
        }
        return ApiResponse<T>(statusCode: response.statusCode);
      }
      return ApiResponse<T>(
        error: parseApiError(defaultErrorMessage, response: response),
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ApiResponse<T>(
        error: parseApiError('Network error', error: e),
        statusCode: -1,
      );
    }
  }

  Future<ApiResponse<T>> delete<T>(
    String path, {
    String defaultErrorMessage = 'DELETE request failed',
  }) async {
    try {
      final reqHeaders = await headers;
      final response = await http.delete(
        Uri.parse(buildUrl(path)),
        headers: reqHeaders,
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResponse<T>(statusCode: response.statusCode);
      }
      return ApiResponse<T>(
        error: parseApiError(defaultErrorMessage, response: response),
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ApiResponse<T>(
        error: parseApiError('Network error', error: e),
        statusCode: -1,
      );
    }
  }
}
