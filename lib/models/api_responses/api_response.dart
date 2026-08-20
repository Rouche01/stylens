import 'package:gostylens/utils/api_utils.dart';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart' as dio;

class ErrorData {
  final String code;
  final String message;

  ErrorData({required this.code, required this.message});

  static const String _defaultFriendlyMessage =
      'Oops! Something went wrong. If this persists, please contact support.';

  static const Map<String, String> _friendlyMessagesByCode = {
    'STYLENS_USER_NOT_FOUND':
        'We couldn\'t find your profile. Please sign up to continue.',
    'NOT_FOUND': 'We couldn\'t find what you\'re looking for. Please try again.',
    'FREE_LIMIT_REACHED':
        'Free limit reached. Please upgrade to a Core plan for unlimited sessions.',
    'MESSAGE_LIMIT_REACHED':
        'You have reached the message limit for this session.',
    'IMAGE_LIMIT_REACHED':
        'You have reached the image limit for this session.',
    'SERVER_ERROR': 'Communication error with the server.',
  };

  static const Map<String, String> _friendlyTitlesByCode = {
    'NETWORK_ERROR': 'Connection Lost',
    'TIMEOUT_ERROR': 'Request Timed Out',
    'FREE_LIMIT_REACHED': 'Limit Reached',
  };

  factory ErrorData.fromJson(Map<String, dynamic> json) {
    return ErrorData(
      code: json['code'] as String,
      message: json['error'] as String,
    );
  }

  String get normalizedCode => code.toUpperCase().trim();

  bool get _isNgrokCode => normalizedCode.startsWith('ERR_NGROK');

  bool get _isTransportMessageCode =>
      normalizedCode == 'NETWORK_ERROR' || normalizedCode == 'TIMEOUT_ERROR';

  String toFriendlyMessage() {
    if (_isNgrokCode) {
      return 'The server is currently offline or the connection was lost. Please try again in a few moments.';
    }

    if (_isTransportMessageCode) {
      return message; // Already friendly
    }

    final mappedMessage = _friendlyMessagesByCode[normalizedCode];
    if (mappedMessage != null) {
      return mappedMessage;
    }

    if (normalizedCode.isEmpty || normalizedCode == 'UNKNOWN') {
      if (message.isNotEmpty) return message;
      return _defaultFriendlyMessage;
    }

    // For unmapped backend codes, keep output safe by default.
    if (message.isEmpty) {
      return _defaultFriendlyMessage;
    }

    final looksLikeTechnicalCode = RegExp(r'^[A-Z0-9_:-]{4,}$').hasMatch(message);
    if (!looksLikeTechnicalCode) {
      return message;
    }

    return _defaultFriendlyMessage;
  }

  @override
  String toString() => toFriendlyMessage();

  String toFriendlyTitle() {
    if (_isNgrokCode) {
      return 'Server Unavailable';
    }
    final mappedTitle = _friendlyTitlesByCode[normalizedCode];
    if (mappedTitle != null) return mappedTitle;
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

  String get errorMessage => error?.toFriendlyMessage() ?? 'Unknown error';
}
