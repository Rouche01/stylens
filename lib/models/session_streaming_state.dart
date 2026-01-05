enum SessionStreamingStatus {
  idle,
  initiating,
  streamStarted,
  streaming,
  completed,
  error,
}

class SessionStreamingState {
  bool isStreaming;
  bool isInitiatingStreaming;
  String streamingText = '';
  String? error;

  SessionStreamingState({
    this.isStreaming = false,
    this.isInitiatingStreaming = false,
    this.error,
    this.streamingText = '',
  });

  SessionStreamingState.initial()
    : isStreaming = false,
      isInitiatingStreaming = false,
      streamingText = '',
      error = null;

  SessionStreamingState.initiateStream()
    : isStreaming = false,
      isInitiatingStreaming = true,
      streamingText = '',
      error = null;

  SessionStreamingState.isStreaming({String? updatedChunk})
    : isStreaming = true,
      isInitiatingStreaming = false,
      streamingText = updatedChunk ?? '',
      error = null;

  SessionStreamingState.completeStream({String? finalChunk})
    : isStreaming = false,
      isInitiatingStreaming = false,
      streamingText = finalChunk ?? '',
      error = null;

  SessionStreamingState.error(String errorMessage)
    : isStreaming = false,
      isInitiatingStreaming = false,
      error = errorMessage;

  SessionStreamingState copyWith({
    bool? isStreaming,
    bool? isInitiatingStreaming,
    String? error,
  }) {
    return SessionStreamingState(
      isStreaming: isStreaming ?? this.isStreaming,
      isInitiatingStreaming:
          isInitiatingStreaming ?? this.isInitiatingStreaming,
      error: error ?? this.error,
    );
  }
}
