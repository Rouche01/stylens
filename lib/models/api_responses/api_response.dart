class ErrorData {
  final String code;
  final String message;

  ErrorData({required this.code, required this.message});

  factory ErrorData.fromJson(Map<String, dynamic> json) {
    print('error data: $json');
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

  bool get isSuccess => statusCode >= 200 && statusCode < 300;
}
