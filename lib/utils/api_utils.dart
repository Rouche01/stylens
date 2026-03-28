import 'dart:convert';
import 'package:gostylens/models/api_responses/api_response.dart';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart' as dio;

import 'package:gostylens/utils/string_extensions.dart';

/// Helper to extract error messages from HTTP responses or raw exceptions.
ErrorData parseApiError(
  String defaultMessage, {
  http.Response? response,
  dio.Response? dioResponse,
  dynamic error,
}) {
  // 1. Handle dio.Response first
  if (dioResponse != null) {
    final data = dioResponse.data;

    if (data is Map<String, dynamic>) {
      if (data['message'] != null) {
        return ErrorData(
          code: data['code']?.toString() ?? 'UNKNOWN',
          message: data['message'].toString(),
        );
      }
      if (data['error'] != null) {
        return ErrorData(
          code: data['code']?.toString() ?? 'UNKNOWN',
          message: data['error'].toString(),
        );
      }
    } else if (data is String) {
      // Check for Ngrok technical error codes in raw strings
      final ngrokMatch = RegExp(r'ERR_NGROK_\d+').firstMatch(data);
      if (ngrokMatch != null) {
        final code = ngrokMatch.group(0)!;
        return ErrorData(
          code: code,
          message: 'Server connection error ($code)',
        );
      }
      if (data.trim().isNotEmpty) {
        return ErrorData(code: 'UNKNOWN', message: data);
      }
    }
  }

  // 2. Handle http.Response (Backward Compat)
  if (response != null) {
    final contentType = response.headers['content-type'];
    if (contentType?.contains('application/json') ?? false) {
      try {
        final data = json.decode(response.body);

        if (data is String) {
          return ErrorData(code: 'UNKNOWN', message: data);
        }

        if (data is Map<String, dynamic>) {
          if (data['message'] != null) {
            return ErrorData(
              code: data['code'] ?? 'UNKNOWN',
              message: data['message'].toString(),
            );
          }
          if (data['error'] != null) {
            return ErrorData(
              code: data['code'] ?? 'UNKNOWN',
              message: data['error'].toString(),
            );
          }
        }
      } catch (_) {
        // If it's not JSON or fails to parse, fall back to default behavior
      }
    } else {
      // It's plain text, HTML, etc. (e.g. Ngrok error page)
      // Extract technical error codes if present (e.g. ERR_NGROK_3200)
      final ngrokMatch = RegExp(r'ERR_NGROK_\d+').firstMatch(response.body);
      if (ngrokMatch != null) {
        final code = ngrokMatch.group(0)!;
        return ErrorData(
          code: code,
          message: 'Server connection error ($code)',
        );
      }
      return ErrorData(code: 'UNKNOWN', message: response.body);
    }
  }

  if (error != null) {
    String message = '$defaultMessage: ${error.toString().cleanException()}';
    String code = 'UNKNOWN';

    if (error is dio.DioException) {
      final dioErr = error;
      switch (dioErr.type) {
        case dio.DioExceptionType.connectionTimeout:
        case dio.DioExceptionType.sendTimeout:
        case dio.DioExceptionType.receiveTimeout:
          message = 'The request timed out. Please try again later.';
          code = 'TIMEOUT_ERROR';
          break;
        case dio.DioExceptionType.connectionError:
          message =
              'Connection failed. Please check your internet connection and try again.';
          code = 'NETWORK_ERROR';
          break;
        case dio.DioExceptionType.badResponse:
          // This should usually be handled via dioResponse, but as a fallback:
          message = 'Server returned an error (${dioErr.response?.statusCode})';
          break;
        default:
          message = 'Network error: ${dioErr.message}';
      }
    } else {
      final errorStr = error.toString().toLowerCase();
      if (errorStr.contains('socketexception') ||
          errorStr.contains('connection refused')) {
        message =
            'Connection failed. Please check your internet connection and try again.';
        code = 'NETWORK_ERROR';
      } else if (errorStr.contains('timeout')) {
        message = 'The request timed out. Please try again later.';
        code = 'TIMEOUT_ERROR';
      } else if (errorStr.contains('httpexception')) {
        message = 'Communication error with the server.';
        code = 'SERVER_ERROR';
      }
    }

    return ErrorData(code: code, message: message);
  }

  return ErrorData(code: 'UNKNOWN', message: defaultMessage);
}
