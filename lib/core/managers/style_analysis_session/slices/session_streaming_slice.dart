import 'dart:convert';

import 'package:gostylens/core/services/api_service/index.dart';
import 'package:gostylens/models/session_streaming_state.dart';
import 'package:gostylens/utils/streaming_utils.dart';

enum ContextMode { recent, all, last }

/// Manages streaming state for all sessions
/// Streaming state is kept locally (not in _stateSlices) since it's per-session
class SessionStreamingSlice {
  final StyleAnalysisApiService _apiService;
  final void Function() _notifyListeners;

  SessionStreamingSlice({
    required StyleAnalysisApiService apiService,
    required void Function() notifyListeners,
  }) : _apiService = apiService,
       _notifyListeners = notifyListeners;

  // --- State ---
  final Map<String, SessionStreamingState> _states = {};

  // --- Getters ---
  bool get hasActiveStreaming => _states.values.any((s) => s.isStreaming);

  List<String> get streamingSessionIds => _states.entries
      .where((e) => e.value.isStreaming)
      .map((e) => e.key)
      .toList();

  List<String> get initiatingSessionIds => _states.entries
      .where((e) => e.value.isInitiatingStreaming)
      .map((e) => e.key)
      .toList();

  SessionStreamingState getState(String sessionId) =>
      _states[sessionId] ?? SessionStreamingState.initial();

  bool isStreaming(String sessionId) => getState(sessionId).isStreaming;

  bool isInitiating(String sessionId) =>
      getState(sessionId).isInitiatingStreaming;

  bool isBusy(String sessionId) =>
      isStreaming(sessionId) || isInitiating(sessionId);

  String? getStreamingText(String sessionId) =>
      getState(sessionId).streamingText;

  // --- Streaming ---
  Future<void> startStreaming({
    required String sessionId,
    required ContextMode contextMode,
    required void Function() onInitiating,
    required void Function(String sessionId, String text) onStreamStarted,
    required void Function(String sessionId, String text) onChunk,
    required void Function(String sessionId, String finalText) onCompleted,
    required void Function(String sessionId, String error) onError,
  }) async {
    try {
      _updateStatus(sessionId, SessionStreamingStatus.initiating);
      onInitiating();

      final response = await _apiService.streamAssistantResponse(
        sessionId: sessionId,
        contextMode: contextMode.name,
      );

      if (response.statusCode == 200) {
        String accumulated = '';
        bool isFirst = true;
        final buffer = SessionStreamBuffer();

        await for (var rawChunk in response.stream.transform(utf8.decoder)) {
          final chunks = buffer.parseChunk(rawChunk, sessionId);

          for (final chunk in chunks) {
            accumulated += chunk.chunkText;

            if (isFirst) {
              _updateStatus(
                chunk.sessionId,
                SessionStreamingStatus.streamStarted,
                updatedChunk: accumulated,
              );
              print('Do we start streaming here?');
              onStreamStarted(chunk.sessionId, accumulated);
              isFirst = false;
            } else {
              _updateStatus(
                chunk.sessionId,
                SessionStreamingStatus.streaming,
                updatedChunk: accumulated,
              );
              onChunk(chunk.sessionId, accumulated);
            }
          }
        }

        buffer.clear();
        _updateStatus(
          sessionId,
          SessionStreamingStatus.completed,
          finalChunk: accumulated,
        );
        onCompleted(sessionId, accumulated);
      } else {
        print(
          'Streaming failed with status: ${response.statusCode} ${response.reasonPhrase}',
        );
        final error = 'Failed: ${response.statusCode}';
        _updateStatus(sessionId, SessionStreamingStatus.error, error: error);
        onError(sessionId, error);
      }
    } catch (e) {
      final error = 'Stream error: $e';
      _updateStatus(sessionId, SessionStreamingStatus.error, error: error);
      onError(sessionId, error);
    }
  }

  void reset(String sessionId) {
    _states[sessionId] = SessionStreamingState.initial();
    _notifyListeners();
  }

  // --- Private ---
  void _updateStatus(
    String sessionId,
    SessionStreamingStatus status, {
    String? error,
    String? updatedChunk,
    String? finalChunk,
  }) {
    _states[sessionId] = switch (status) {
      SessionStreamingStatus.idle => SessionStreamingState.initial(),
      SessionStreamingStatus.initiating =>
        SessionStreamingState.initiateStream(),
      SessionStreamingStatus.streaming ||
      SessionStreamingStatus.streamStarted => SessionStreamingState.isStreaming(
        updatedChunk: updatedChunk,
      ),
      SessionStreamingStatus.completed => SessionStreamingState.completeStream(
        finalChunk: finalChunk,
      ),
      SessionStreamingStatus.error => SessionStreamingState.error(
        error ?? 'Unknown error',
      ),
    };
    _notifyListeners();
  }
}
