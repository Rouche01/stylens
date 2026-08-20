import 'package:gostylens/models/api_responses/api_response.dart';
import 'package:gostylens/utils/api_utils.dart';

enum MessageErrorType {
  freeLimitReached('FREE_LIMIT_REACHED'),
  failedFetch('FAILED_FETCH'),
  network('NETWORK'),
  generic('GENERIC'),
  streaming('STREAMING'),
  timeout('TIMEOUT'),
  unknown('UNKNOWN');

  final String value;
  const MessageErrorType(this.value);

  static const Map<String, MessageErrorType> _codeAliases = {
    'NETWORK_ERROR': MessageErrorType.network,
    'TIMEOUT_ERROR': MessageErrorType.timeout,
    'SESSION_LIMIT_REACHED': MessageErrorType.freeLimitReached,
    'MESSAGE_LIMIT_REACHED': MessageErrorType.freeLimitReached,
    'IMAGE_LIMIT_REACHED': MessageErrorType.freeLimitReached,
  };

  factory MessageErrorType.fromValue(String value) {
    final normalized = value.toUpperCase();
    final alias = _codeAliases[normalized];
    if (alias != null) return alias;
    return MessageErrorType.values.firstWhere(
      (e) => e.value == normalized,
      orElse: () => MessageErrorType.unknown,
    );
  }
}

class StyleAnalysisSessionMessageError {
  final String message;
  final MessageErrorType type;

  const StyleAnalysisSessionMessageError({
    required this.message,
    this.type = MessageErrorType.generic,
  });

  bool get isFreeLimitReached => type == MessageErrorType.freeLimitReached;

  /// Detects the error type from a raw error string
  factory StyleAnalysisSessionMessageError.fromRawError(
    String errorMessage, [
    String? errorCode,
  ]) {
    MessageErrorType type = MessageErrorType.generic;

    if (errorCode != null) {
      type = MessageErrorType.fromValue(errorCode);
    } else if (errorMessage.contains('FREE_LIMIT_REACHED')) {
      type = MessageErrorType.fromValue('FREE_LIMIT_REACHED');
    }

    return StyleAnalysisSessionMessageError(message: errorMessage, type: type);
  }

  factory StyleAnalysisSessionMessageError.fromCaughtError(Object error) {
    if (error is ErrorData) {
      return StyleAnalysisSessionMessageError.fromRawError(
        error.toFriendlyMessage(),
        error.code,
      );
    }

    return StyleAnalysisSessionMessageError.fromRawError(
      friendlyErrorMessage(error),
    );
  }
}
