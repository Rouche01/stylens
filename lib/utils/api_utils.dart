import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:gostylens/utils/string_extensions.dart';

/// Helper to extract error messages from HTTP responses or raw exceptions.
String parseApiError(
  String defaultMessage, {
  http.Response? response,
  dynamic error,
}) {
  if (response != null) {
    try {
      final data = json.decode(response.body);
      if (data['message'] != null) return data['message'];
      if (data['error'] != null) return data['error'];
    } catch (_) {
      // If it's not JSON or fails to parse, fall back to default behavior
    }
    return '$defaultMessage: ${response.statusCode} - ${response.body}';
  }

  if (error != null) {
    return '$defaultMessage: ${error.toString().cleanException()}';
  }

  return defaultMessage;
}
