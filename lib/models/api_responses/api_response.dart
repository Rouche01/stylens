import 'package:gostylens/utils/api_utils.dart';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart' as dio;

class ErrorData {
  final String code;
  final String message;

  ErrorData({required this.code, required this.message});

  factory ErrorData.fromJson(Map<String, dynamic> json) {
    return ErrorData(
      code: json['code'] as String,
      message: json['error'] as String,
    );
  }

  String toFriendlyMessage() {
    // Ngrok down / Tunnel issues
    if (code.startsWith('ERR_NGROK')) {
      return 'The server is currently offline or the connection was lost. Please try again in a few moments.';
    }

    // Network / Socket issues
    if (code == 'NETWORK_ERROR' || code == 'TIMEOUT_ERROR') {
      return message; // Already friendly
    }

    // Backend specific errors (if you add more later)
    if (code == 'STYLENS_USER_NOT_FOUND') {
      return 'We couldn\'t find your profile. Please sign up to continue.';
    }

    // Default fallback - showing the original message if it's not a technical code
    if (code == 'UNKNOWN' || code.isEmpty) {
      return message;
    }

    return 'Oops! Something went wrong. If this persists, please contact support.';
  }

  String toFriendlyTitle() {
    if (code.startsWith('ERR_NGROK')) {
      return 'Server Unavailable';
    }
    if (code == 'NETWORK_ERROR') {
      return 'Connection Lost';
    }
    if (code == 'TIMEOUT_ERROR') {
      return 'Request Timed Out';
    }
    return 'Unable to Connect';
  }
}

class ApiResponse<T> {
  final T? data;
  final ErrorData? error;
  final int statusCode;

  ApiResponse({this.data, this.error, required this.statusCode});

  ApiResponse.success(this.data, {this.statusCode = 200}) : error = null;

  ApiResponse.error({
    required String defaultMessage,
    http.Response? response,
    dio.Response? dioResponse,
    dynamic error,
    this.statusCode = -1,
  }) : data = null,
       error = parseApiError(
         ApiErrorInput(
           defaultMessage: defaultMessage,
           error: error,
           dioResponse: dioResponse,
         ),
       );

  bool get isSuccess =>
      (statusCode >= 200 && statusCode < 300) || statusCode == 304;

  String get errorMessage => error?.message ?? 'Unknown error';
}
