import 'dart:io';

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:gostylens/core/services/style_analysis_api_service.dart';
import 'package:gostylens/models/action_state.dart';
import 'package:gostylens/models/style_analysis_session_message.dart';
import 'package:gostylens/models/remote_image.dart';
import 'package:gostylens/models/selected_session.dart';
import 'package:gostylens/models/session_streaming_state.dart';
import 'package:gostylens/models/session_ui_state.dart';
import 'package:gostylens/models/style_analysis_session.dart';
import 'package:gostylens/utils/streaming_utils.dart';

enum ContextMode { recent, all, last }

enum ManagerStateSliceName {
  sessions,
  selectedSession,
  createSession,
  addMessageToSession,
  deleteSession,
}

enum StateUpdateType { loading, success, error, initial }

// Deprecated: Use slice managers instead
class StyleAnalysisSessionManager extends ChangeNotifier {
  // --- Config ---
  // Temporary user ID for testing purposes
  static const String tempUserId = 'day2TestId5';
  static const _initialStyleAnalysisPrompt =
      'What do you think about my outfit?';

  static const _initialBotReply =
      "Looking great! 🔥 What's the occasion for this outfit?";

  // --- API Service ---
  final StyleAnalysisApiService _apiService = StyleAnalysisApiService(
    userId: tempUserId,
  );

  // --- State Slices ---
  final Map<ManagerStateSliceName, ActionState<dynamic>> _stateSlices = {
    ManagerStateSliceName.sessions: ActionState<List<StyleAnalysisSession>>(),
    ManagerStateSliceName.selectedSession:
        ActionState<SelectedStyleAnalysisSession>(),
    ManagerStateSliceName.createSession: ActionState<void>(),
    ManagerStateSliceName.addMessageToSession: ActionState<void>(),
    ManagerStateSliceName.deleteSession: ActionState<void>(),
  };

  // --- Session UI States ---
  final Map<String, SessionUIState> _sessionUIStates = {};

  // --- Streaming State ---
  final Map<String, SessionStreamingState> _streamingStates = {};

  // --- General State ---
  String? _error;

  // --- Session Getters ---
  List<StyleAnalysisSession> get sessions =>
      _getStateSlice<List<StyleAnalysisSession>>(
        ManagerStateSliceName.sessions,
      ).data ??
      [];

  bool get isCreatingSession =>
      _getStateSlice<void>(ManagerStateSliceName.createSession).isLoading;

  bool get isSessionsLoading => _getStateSlice<List<StyleAnalysisSession>>(
    ManagerStateSliceName.sessions,
  ).isLoading;

  String? get sessionsError => _getStateSlice<List<StyleAnalysisSession>>(
    ManagerStateSliceName.sessions,
  ).error;

  // --- Selected Session Getters ---
  SelectedStyleAnalysisSession? get selectedSession =>
      _getStateSlice<SelectedStyleAnalysisSession>(
        ManagerStateSliceName.selectedSession,
      ).data;

  String? get selectedSessionId => selectedSession?.sessionId;

  List<StyleAnalysisSessionMessage> get selectedSessionMessages =>
      selectedSession?.messages ?? [];

  bool get isSelectedSessionLoading =>
      _getStateSlice<SelectedStyleAnalysisSession>(
        ManagerStateSliceName.selectedSession,
      ).isLoading;

  bool get isSelectedSessionStreaming {
    final sessionId = selectedSession?.sessionId;
    if (sessionId == null) return false;
    return _getSessionStreamingState(sessionId).isStreaming;
  }

  String? get selectedSessionStreamingText {
    final sessionId = selectedSession?.sessionId;
    if (sessionId == null) return null;
    return _getSessionStreamingState(sessionId).streamingText;
  }

  String? get selectedSessionError =>
      _getStateSlice<SelectedStyleAnalysisSession>(
        ManagerStateSliceName.selectedSession,
      ).error;

  String? get selectedSessionDraftText {
    final sessionId = selectedSession?.sessionId;
    if (sessionId == null) return null;
    return _getSessionUIState(sessionId).draftText;
  }

  bool get isSelectedSessionAwaitingResponse {
    final isInitiatingStreamForSelectedSession =
        selectedSessionId != null &&
        initiatingStreamingSessionIds.contains(selectedSessionId);

    return isCreatingSession || isInitiatingStreamForSelectedSession;
  }

  // --- Streaming Getters ---
  bool get hasActiveStreaming =>
      _streamingStates.values.any((s) => s.isStreaming);

  List<String> get streamingSessionIds => _streamingStates.entries
      .where((e) => e.value.isStreaming)
      .map((e) => e.key)
      .toList();

  List<String> get initiatingStreamingSessionIds => _streamingStates.entries
      .where((e) => e.value.isInitiatingStreaming)
      .map((e) => e.key)
      .toList();

  String? get error => _error;

  // --- Sessions Operations ---
  Future<String?> createSession({String? title}) async {
    // Extract messages to send before appending loading message
    final messages = selectedSession?.messages ?? [];

    _updateState(
      ManagerStateSliceName.createSession,
      StateUpdateType.loading,
      appendLoadingMessage: true,
    );

    // Convert StyleAnalysisSessionMessage list to MessageEntry format
    final messageEntries = messages.map((msg) {
      return {
        'role': msg.role.name,
        'prompt': msg.text,
        'remoteImage': msg.remoteImage != null
            ? {'url': msg.remoteImage!.url, 'key': msg.remoteImage!.key}
            : null,
      };
    }).toList();

    final response = await _apiService.createSession(messages: messageEntries);

    if (response.isSuccess && response.data != null) {
      final sessionId = response.data!;

      _updateState<SelectedStyleAnalysisSession>(
        ManagerStateSliceName.selectedSession,
        StateUpdateType.success,
        data: SelectedStyleAnalysisSession(
          sessionId: sessionId,
          messages: messages,
        ),
      );

      _updateState<void>(
        ManagerStateSliceName.createSession,
        StateUpdateType.success,
      );

      streamAssistantResponse(sessionId, contextMode: ContextMode.all);
      fetchSessions();

      return sessionId;
    } else {
      _updateState(
        ManagerStateSliceName.createSession,
        StateUpdateType.error,
        error:
            response.error ?? 'Unknown error occurred while creating session',
        clearLoadingMessage: true,
      );
      return null;
    }
  }

  Future<void> fetchSessions() async {
    _updateState<List<StyleAnalysisSession>>(
      ManagerStateSliceName.sessions,
      StateUpdateType.loading,
    );

    final response = await _apiService.fetchSessions();

    if (response.isSuccess && response.data != null) {
      final paginatedResponse = response.data!;

      // Sort by most recent first
      paginatedResponse.items.sort(
        (a, b) => b.updatedAt.compareTo(a.updatedAt),
      );
      _updateState<List<StyleAnalysisSession>>(
        ManagerStateSliceName.sessions,
        StateUpdateType.success,
        data: paginatedResponse.items,
      );
    } else {
      _updateState(
        ManagerStateSliceName.sessions,
        StateUpdateType.error,
        error:
            response.error ?? 'Failed to load sessions: ${response.statusCode}',
      );
    }
  }

  Future<bool> deleteSession(String sessionId) async {
    _updateState<void>(
      ManagerStateSliceName.deleteSession,
      StateUpdateType.loading,
    );
    final response = await _apiService.deleteSession(sessionId);

    if (response.isSuccess) {
      // Remove from local list
      final updatedSessions = sessions.where((s) => s.id != sessionId).toList();

      _updateState<List<StyleAnalysisSession>>(
        ManagerStateSliceName.sessions,
        StateUpdateType.success,
        data: updatedSessions,
      );
      return true;
    } else {
      _updateState<void>(
        ManagerStateSliceName.deleteSession,
        StateUpdateType.error,
        error:
            response.error ??
            'Failed to delete session: ${response.statusCode}',
      );
      return false;
    }
  }

  // --- Selected Session Operations ---
  void setSelectedSessionId(String sessionId) {
    _updateState<SelectedStyleAnalysisSession>(
      ManagerStateSliceName.selectedSession,
      StateUpdateType.success,
      data: SelectedStyleAnalysisSession(
        sessionId: sessionId,
        messages: [], // Messages will be loaded separately
      ),
    );

    _syncStreamingStateToMessages(sessionId);
  }

  Future<bool> fetchSelectedSessionMessages() async {
    final sessionId = selectedSessionId;
    if (sessionId == null) {
      _updateState(
        ManagerStateSliceName.selectedSession,
        StateUpdateType.error,
        error: 'No session selected',
      );
      return false;
    }

    final isStreaming = _getSessionStreamingState(sessionId).isStreaming;

    _updateState<SelectedStyleAnalysisSession>(
      ManagerStateSliceName.selectedSession,
      StateUpdateType.loading,
      data: SelectedStyleAnalysisSession(sessionId: sessionId, messages: []),
    );

    final response = await _apiService.fetchSessionMessages(sessionId);

    if (response.isSuccess && response.data != null) {
      _updateState<SelectedStyleAnalysisSession>(
        ManagerStateSliceName.selectedSession,
        StateUpdateType.success,
        data: SelectedStyleAnalysisSession.fromJson({
          'session_id': sessionId,
          'messages': response.data?.items ?? [],
        }),
        appendLoadingMessage: isSelectedSessionAwaitingResponse,
        clearLoadingMessage: !isSelectedSessionAwaitingResponse,
      );

      // Sync any active streaming state to the messages
      if (isStreaming) {
        syncStreamingStateAfterFetch();
      }

      return true;
    } else {
      _updateState(
        ManagerStateSliceName.selectedSession,
        StateUpdateType.error,
        error:
            response.error ?? 'Failed to load messages: ${response.statusCode}',
        data: SelectedStyleAnalysisSession(sessionId: sessionId, messages: []),
      );
      return false;
    }
  }

  Future<void> addMessageToSelectedSession(
    StyleAnalysisSessionMessage message, {
    bool remoteUpdate = true,
  }) async {
    final sessionId = selectedSessionId;

    if (sessionId == null) {
      _updateState(
        ManagerStateSliceName.addMessageToSession,
        StateUpdateType.error,
        error: 'No session selected',
      );
      return;
    }

    addToSelectedSessionMessages(message);

    if (!remoteUpdate) return;

    _updateState<void>(
      ManagerStateSliceName.addMessageToSession,
      StateUpdateType.loading,
      appendLoadingMessage: true,
    );

    final messageData = {
      'role': message.role.name,
      'prompt': message.text,
      'remoteImage': message.remoteImage != null
          ? {'url': message.remoteImage!.url, 'key': message.remoteImage!.key}
          : null,
    };

    final response = await _apiService.addMessageToSession(
      sessionId: sessionId,
      message: messageData,
    );

    if (response.isSuccess) {
      _updateState<void>(
        ManagerStateSliceName.addMessageToSession,
        StateUpdateType.success,
      );
      streamSelectedSessionResponse();
    } else {
      _updateState(
        ManagerStateSliceName.addMessageToSession,
        StateUpdateType.error,
        error:
            response.error ?? 'Failed to add message: ${response.statusCode}',
        clearLoadingMessage: true,
      );
    }
  }

  Future<void> streamSelectedSessionResponse({
    ContextMode contextMode = ContextMode.recent,
  }) async {
    final sessionId = selectedSessionId;

    if (sessionId == null) {
      _setError('No session selected for streaming');
      return;
    }

    await streamAssistantResponse(sessionId, contextMode: contextMode);
  }

  void disposeSelectedSession({String? messageInputText}) {
    if (selectedSession?.sessionId != null) {
      _setSessionUIState(
        selectedSession!.sessionId!,
        draftText: messageInputText ?? '',
      );
    }

    _updateState<SelectedStyleAnalysisSession>(
      ManagerStateSliceName.selectedSession,
      StateUpdateType.initial,
    );
  }

  // --- Streaming Operations ---
  Future<void> streamAssistantResponse(
    String sessionId, {
    ContextMode contextMode = ContextMode.recent,
    VoidCallback? onComplete,
  }) async {
    try {
      _updateSessionStreamingStatus(
        sessionId,
        SessionStreamingStatus.initiating,
      );

      final streamedResponse = await _apiService.streamAssistantResponse(
        sessionId: sessionId,
        contextMode: contextMode.name,
      );

      if (streamedResponse.statusCode == 200) {
        int chunkCount = 0;
        String accumulatedText = '';
        bool isFirstChunk = true;
        final sessionStreamBuffer = SessionStreamBuffer();

        await for (var rawChunk in streamedResponse.stream.transform(
          utf8.decoder,
        )) {
          chunkCount++;
          print('Received raw chunk #$chunkCount: $rawChunk');

          final parsedChunks = sessionStreamBuffer.parseChunk(
            rawChunk,
            sessionId,
          );

          for (final parsedChunk in parsedChunks) {
            accumulatedText += parsedChunk.chunkText;
            print(
              'Parsed chunk text: "${parsedChunk.chunkText}" for session: ${parsedChunk.sessionId}',
            );

            if (isFirstChunk) {
              _updateSessionStreamingStatus(
                parsedChunk.sessionId,
                SessionStreamingStatus.streamStarted,
                updatedChunk: accumulatedText,
              );
              isFirstChunk = false;
            } else {
              _updateSessionStreamingStatus(
                parsedChunk.sessionId,
                SessionStreamingStatus.streaming,
                updatedChunk: accumulatedText,
              );
            }
          }
        }

        //Clear the buffer
        sessionStreamBuffer.clear();

        _updateSessionStreamingStatus(
          sessionId,
          SessionStreamingStatus.completed,
          finalChunk: accumulatedText,
        );

        onComplete?.call();
      } else {
        _updateSessionStreamingStatus(
          sessionId,
          SessionStreamingStatus.error,
          error: 'Failed to get AI response: ${streamedResponse.statusCode}',
        );
      }
    } catch (e) {
      _updateSessionStreamingStatus(
        sessionId,
        SessionStreamingStatus.error,
        error: 'Failed to stream AI response: $e',
      );
    }
  }

  void syncStreamingStateAfterFetch() {
    final sessionId = selectedSessionId;
    if (sessionId == null) return;

    final streamingState = _getSessionStreamingState(sessionId);

    if (!streamingState.isStreaming || streamingState.streamingText.isEmpty) {
      return;
    }

    final messages = selectedSessionMessages;

    // If there's no loading message and no bot message being updated, add one
    if (messages.isEmpty) {
      addToSelectedSessionMessages(
        StyleAnalysisSessionMessage(
          role: UserRole.assistant,
          text: streamingState.streamingText,
          timestamp: DateTime.now(),
        ),
      );
      return;
    }

    final lastMessage = messages.last;

    // If last message is a loading message, replace it with streaming text
    if (lastMessage.isLoading) {
      _removeLoadingMessage();
      addToSelectedSessionMessages(
        StyleAnalysisSessionMessage(
          role: UserRole.assistant,
          text: streamingState.streamingText,
          timestamp: DateTime.now(),
        ),
      );
      return;
    }

    // If last message is a bot message, update it with the streaming text
    if (!lastMessage.isUserMessage) {
      _replaceLastBotMessageWithChunk(sessionId, streamingState.streamingText);
      return;
    }

    // If last message is user message, add a new bot message with streaming text
    addToSelectedSessionMessages(
      StyleAnalysisSessionMessage(
        role: UserRole.assistant,
        text: streamingState.streamingText,
        timestamp: DateTime.now(),
      ),
    );
  }

  // --- Helpers ---
  void addToSelectedSessionMessages(StyleAnalysisSessionMessage message) {
    print(
      'Adding message to selected session: ${selectedSession?.sessionId} with message: ${message.text}',
    );
    _updateState<SelectedStyleAnalysisSession>(
      ManagerStateSliceName.selectedSession,
      StateUpdateType.success,
      data: SelectedStyleAnalysisSession(
        sessionId: selectedSession?.sessionId,
        messages: [...?selectedSession?.messages, message],
      ),
    );
  }

  void initializeNewSession(
    File? outfitImageFile,
    RemoteImage? outfitRemoteImage,
  ) {
    addToSelectedSessionMessages(
      StyleAnalysisSessionMessage(
        role: UserRole.user,
        timestamp: DateTime.now(),
        imageFile: outfitImageFile,
        remoteImage: outfitRemoteImage,
        text: _initialStyleAnalysisPrompt,
      ),
    );

    addToSelectedSessionMessages(
      StyleAnalysisSessionMessage(
        role: UserRole.system,
        timestamp: DateTime.now(),
        text: _initialBotReply,
      ),
    );
  }

  void _setSessionUIState(String sessionId, {String draftText = ''}) {
    final prevSessionUIState = _sessionUIStates[sessionId] ?? SessionUIState();
    _sessionUIStates[sessionId] = prevSessionUIState.copyWith(
      draftText: draftText,
    );
    notifyListeners();
  }

  SessionUIState _getSessionUIState(String sessionId) {
    final sessionUIState = _sessionUIStates[sessionId];
    return sessionUIState ?? SessionUIState();
  }

  void _clearError() => _setError(null);

  void _setError(String? error) {
    if (_error != error) {
      _error = error;
      notifyListeners();
    }
  }

  void _addLoadingMessage() {
    final messages =
        _getStateSlice<SelectedStyleAnalysisSession>(
          ManagerStateSliceName.selectedSession,
        ).data?.messages ??
        [];

    // Avoid adding multiple loading bubbles
    if (messages.isNotEmpty && messages.last.isLoading) return;

    final loadingMessage = StyleAnalysisSessionMessage(
      role: UserRole.assistant,
      isLoading: true,
      timestamp: DateTime.now(),
    );
    addToSelectedSessionMessages(loadingMessage);
  }

  void _removeLoadingMessage() {
    final messages =
        _getStateSlice<SelectedStyleAnalysisSession>(
          ManagerStateSliceName.selectedSession,
        ).data?.messages ??
        [];
    if (messages.isNotEmpty && messages.last.isLoading) {
      _updateState<SelectedStyleAnalysisSession>(
        ManagerStateSliceName.selectedSession,
        StateUpdateType.success,
        data: SelectedStyleAnalysisSession(
          sessionId: _getStateSlice<SelectedStyleAnalysisSession>(
            ManagerStateSliceName.selectedSession,
          ).data?.sessionId,
          messages: messages.sublist(0, messages.length - 1),
        ),
      );
    }
  }

  void _replaceLastBotMessageWithChunk(String? sessionId, String updatedChunk) {
    final selectedSession = _getStateSlice<SelectedStyleAnalysisSession>(
      ManagerStateSliceName.selectedSession,
    ).data;

    // Only update messages if this is the currently selected session
    if (selectedSession?.sessionId != sessionId) {
      print('Session $sessionId is not selected, skipping message update');
      return;
    }

    final messages = selectedSession?.messages ?? [];

    // If no messages, add a new bot message
    if (messages.isEmpty) {
      addToSelectedSessionMessages(
        StyleAnalysisSessionMessage(
          role: UserRole.assistant,
          text: updatedChunk,
          timestamp: DateTime.now(),
        ),
      );
      return;
    }

    print('Replacing last bot message with chunk: $updatedChunk $sessionId');

    // If last message is user message, add a new bot message
    if (messages.last.isUserMessage) {
      addToSelectedSessionMessages(
        StyleAnalysisSessionMessage(
          role: UserRole.assistant,
          text: updatedChunk,
          timestamp: DateTime.now(),
        ),
      );
      return;
    }

    // Replace the last bot message
    final lastBotMessage = messages.last;
    final updatedBotMessage = StyleAnalysisSessionMessage(
      role: UserRole.assistant,
      text: updatedChunk,
      timestamp: lastBotMessage.timestamp,
    );

    _updateState<SelectedStyleAnalysisSession>(
      ManagerStateSliceName.selectedSession,
      StateUpdateType.success,
      data: SelectedStyleAnalysisSession(
        sessionId: selectedSession?.sessionId,
        messages: [
          ...messages.sublist(0, messages.length - 1),
          updatedBotMessage,
        ],
      ),
    );
  }

  void _updateSessionStreamingStatus(
    String sessionId,
    SessionStreamingStatus status, {
    String? error,
    String? updatedChunk,
    String? finalChunk,
  }) {
    switch (status) {
      case SessionStreamingStatus.idle:
        _streamingStates[sessionId] = SessionStreamingState.initial();
      case SessionStreamingStatus.initiating:
        _streamingStates[sessionId] = SessionStreamingState.initiateStream();
        _addLoadingMessage();
      case SessionStreamingStatus.streaming:
        _streamingStates[sessionId] = SessionStreamingState.isStreaming(
          updatedChunk: updatedChunk,
        );
        _replaceLastBotMessageWithChunk(sessionId, updatedChunk ?? '');
      case SessionStreamingStatus.streamStarted:
        _streamingStates[sessionId] = SessionStreamingState.isStreaming(
          updatedChunk: updatedChunk,
        );
        _removeLoadingMessage();
        addToSelectedSessionMessages(
          StyleAnalysisSessionMessage(
            role: UserRole.assistant,
            text: updatedChunk ?? '',
            timestamp: DateTime.now(),
          ),
        );
      case SessionStreamingStatus.completed:
        _streamingStates[sessionId] = SessionStreamingState.completeStream(
          finalChunk: finalChunk,
        );
        // Update the last message with the final chunk instead of refetching
        if (finalChunk != null) {
          _replaceLastBotMessageWithChunk(sessionId, finalChunk);
        }
        _removeLoadingMessage();
      case SessionStreamingStatus.error:
        _streamingStates[sessionId] = SessionStreamingState.error(
          error ?? 'Unknown streaming error',
        );
        _removeLoadingMessage();
    }
    notifyListeners();
  }

  SessionStreamingState _getSessionStreamingState(String sessionId) {
    return _streamingStates[sessionId] ?? SessionStreamingState.initial();
  }

  void _syncStreamingStateToMessages(String sessionId) {
    final streamingState = _getSessionStreamingState(sessionId);

    if (streamingState.isStreaming && streamingState.streamingText.isNotEmpty) {
      print(
        'Syncing streaming state for session $sessionId: ${streamingState.streamingText}',
      );

      // We need to wait for messages to be fetched first, then sync
      // This will be called again after fetchSelectedSessionMessages completes
    }
  }

  void _updateState<T>(
    ManagerStateSliceName sliceName,
    StateUpdateType updateType, {
    T? data,
    String? error,
    bool appendLoadingMessage = false,
    bool clearLoadingMessage = false,
  }) {
    switch (updateType) {
      case StateUpdateType.initial:
        _stateSlices[sliceName] = ActionState<T>.initial();
      case StateUpdateType.loading:
        _stateSlices[sliceName] = ActionState<T>.loading();
      case StateUpdateType.success:
        _stateSlices[sliceName] = ActionState<T>.success(data);
      case StateUpdateType.error:
        _stateSlices[sliceName] = ActionState<T>.error(error);
    }

    if (updateType != StateUpdateType.success && data != null) {
      final prev = _stateSlices[sliceName] as ActionState<T>;
      _stateSlices[sliceName] = prev.copyWith(data: data, error: error);
    }

    if (appendLoadingMessage) {
      _addLoadingMessage();
    }

    if (clearLoadingMessage) {
      _removeLoadingMessage();
    }

    notifyListeners();
  }

  ActionState<T> _getStateSlice<T>(ManagerStateSliceName sliceName) {
    return _stateSlices[sliceName] as ActionState<T>;
  }
}
