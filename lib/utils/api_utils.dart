import 'dart:convert';
import 'package:gostylens/models/api_responses/api_response.dart';
import 'package:http/http.dart' as http;

import 'package:gostylens/utils/string_extensions.dart';

/// Helper to extract error messages from HTTP responses or raw exceptions.
ErrorData parseApiError(
  String defaultMessage, {
  http.Response? response,
  dynamic error,
}) {
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
    final errorStr = error.toString().toLowerCase();
    String message = '$defaultMessage: ${error.toString().cleanException()}';
    String code = 'UNKNOWN';

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

    return ErrorData(code: code, message: message);
  }

  return ErrorData(code: 'UNKNOWN', message: defaultMessage);
}
