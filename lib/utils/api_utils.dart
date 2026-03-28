import 'dart:convert';
import 'package:gostylens/models/api_responses/api_response.dart';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart' as dio;

import 'package:gostylens/utils/string_extensions.dart';

class ApiErrorInput {
  final String defaultMessage;
  final http.Response? response;
  final dio.Response? dioResponse;
  final dynamic error;

  ApiErrorInput({
    required this.defaultMessage,
    this.response,
    this.dioResponse,
    this.error,
  });
}

/// Helper to extract error messages from HTTP responses or raw exceptions.
ErrorData parseApiError(ApiErrorInput input) {
  // 1. Handle dio.Response first
  if (input.dioResponse != null) {
    final data = input.dioResponse!.data;

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
  if (input.response != null) {
    final contentType = input.response!.headers['content-type'];
    if (contentType?.contains('application/json') ?? false) {
      try {
        final data = json.decode(input.response!.body);

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
      final ngrokMatch = RegExp(
        r'ERR_NGROK_\d+',
      ).firstMatch(input.response!.body);
      if (ngrokMatch != null) {
        final code = ngrokMatch.group(0)!;
        return ErrorData(
          code: code,
          message: 'Server connection error ($code)',
        );
      }
      return ErrorData(code: 'UNKNOWN', message: input.response!.body);
    }
  }

  if (input.error != null) {
    String message =
        '${input.defaultMessage}: ${input.error.toString().cleanException()}';
    String code = 'UNKNOWN';

    if (input.error is dio.DioException) {
      final dioErr = input.error;
      switch (dioErr.type) {
        case dio.DioExceptionType.connectionTimeout:
        case dio.DioExceptionType.sendTimeout:
        case dio.DioExceptionType.receiveTimeout:
          message = 'The request timed out. Please try again later.';
          code = 'TIMEOUT_ERROR';
        case dio.DioExceptionType.connectionError:
          message =
              'Connection failed. Please check your internet connection and try again.';
          code = 'NETWORK_ERROR';
        case dio.DioExceptionType.badResponse:
          // This should usually be handled via dioResponse, but as a fallback:
          message = 'Server returned an error (${dioErr.response?.statusCode})';
        default:
          message = 'Network error: ${dioErr.message}';
      }
    } else {
      final errorStr = input.error.toString().toLowerCase();
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

  return ErrorData(code: 'UNKNOWN', message: input.defaultMessage);
}
