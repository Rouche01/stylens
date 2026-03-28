enum MessageErrorType {
  freeLimitReached('FREE_LIMIT_REACHED'),
  failedFetch('FAILED_FETCH'),
  network('NETWORK'),
  generic('GENERIC'),
  unknown('UNKNOWN');

  final String value;
  const MessageErrorType(this.value);

  factory MessageErrorType.fromValue(String value) {
    return MessageErrorType.values.firstWhere(
      (e) => e.value == value.toUpperCase(),
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
    String errorMessage,
    String? errorCode,
  ) {
    MessageErrorType type = MessageErrorType.generic;

    if (errorCode != null) {
      type = MessageErrorType.fromValue(errorCode);
    } else if (errorMessage.contains('FREE_LIMIT_REACHED')) {
      type = MessageErrorType.fromValue('FREE_LIMIT_REACHED');
    }

    return StyleAnalysisSessionMessageError(message: errorMessage, type: type);
  }
}
