enum MessageErrorType { freeLimitReached, network, generic }

class StyleAnalysisSessionMessageError {
  final String message;
  final MessageErrorType type;

  const StyleAnalysisSessionMessageError({
    required this.message,
    this.type = MessageErrorType.generic,
  });

  bool get isFreeLimitReached => type == MessageErrorType.freeLimitReached;

  /// Detects the error type from a raw error string
  factory StyleAnalysisSessionMessageError.fromRawError(String errorMessage) {
    final type = errorMessage.contains('FREE_LIMIT_REACHED')
        ? MessageErrorType.freeLimitReached
        : MessageErrorType.generic;

    return StyleAnalysisSessionMessageError(message: errorMessage, type: type);
  }
}
