import 'dart:io';

import 'package:flutter/material.dart';
import 'package:stylens_app/core/services/style_analysis_api_service.dart';
import 'package:stylens_app/models/action_state.dart';
import 'package:stylens_app/models/chat_message.dart';
import 'package:stylens_app/models/remote_image.dart';
import 'package:stylens_app/models/selected_session.dart';
import 'package:stylens_app/models/session_streaming_state.dart';
import 'package:stylens_app/models/style_analysis_session.dart';

import 'slices/selected_session_slice.dart';
import 'slices/session_streaming_slice.dart';
import 'slices/sessions_slice.dart';

enum ManagerStateSliceName {
  sessions,
  selectedSession,
  createSession,
  addMessageToSession,
  deleteSession,
}

class StyleAnalysisSessionManager extends ChangeNotifier {
  static const String tempUserId = 'day2TestId5';

  // --- API Service ---
  late final StyleAnalysisApiService _apiService;

  // --- State Slices (unified storage) ---
  final Map<ManagerStateSliceName, ActionState<dynamic>> _stateSlices = {
    ManagerStateSliceName.sessions: ActionState<List<StyleAnalysisSession>>(),
    ManagerStateSliceName.selectedSession:
        ActionState<SelectedStyleAnalysisSession>(),
    ManagerStateSliceName.createSession: ActionState<void>(),
    ManagerStateSliceName.addMessageToSession: ActionState<void>(),
    ManagerStateSliceName.deleteSession: ActionState<void>(),
  };

  // --- Slice Managers ---
  late final SessionsSlice _sessionsSlice;
  late final SelectedSessionSlice _selectedSessionSlice;
  late final SessionStreamingSlice _streamingSlice;

  StyleAnalysisSessionManager() {
    _apiService = StyleAnalysisApiService(userId: tempUserId);

    _streamingSlice = SessionStreamingSlice(
      apiService: _apiService,
      notifyListeners: notifyListeners,
    );

    _sessionsSlice = SessionsSlice(
      apiService: _apiService,
      getState: () =>
          _stateSlices[ManagerStateSliceName.sessions]
              as ActionState<List<StyleAnalysisSession>>,
      setState: (state) => _stateSlices[ManagerStateSliceName.sessions] = state,
      notifyListeners: notifyListeners,
    );

    _selectedSessionSlice = SelectedSessionSlice(
      apiService: _apiService,
      getState: () =>
          _stateSlices[ManagerStateSliceName.selectedSession]
              as ActionState<SelectedStyleAnalysisSession>,
      setState: (state) =>
          _stateSlices[ManagerStateSliceName.selectedSession] = state,
      notifyListeners: notifyListeners,
    );
  }

  // ============================================================
  // SESSIONS - Getters
  // ============================================================
  List<StyleAnalysisSession> get sessions => _sessionsSlice.sessions;
  bool get isSessionsLoading => _sessionsSlice.isLoading;
  String? get sessionsError => _sessionsSlice.error;

  // ============================================================
  // SELECTED SESSION - Getters
  // ============================================================
  String? get selectedSessionId => _selectedSessionSlice.sessionId;
  List<ChatMessage> get selectedSessionMessages =>
      _selectedSessionSlice.messages;
  bool get isSelectedSessionLoading => _selectedSessionSlice.isLoading;
  String? get selectedSessionError => _selectedSessionSlice.error;
  String? get selectedSessionDraftText => _selectedSessionSlice.draftText;

  bool get isCreatingSession =>
      (_stateSlices[ManagerStateSliceName.createSession] as ActionState<void>)
          .isLoading;

  // ============================================================
  // STREAMING - Getters
  // ============================================================
  bool get hasActiveStreaming => _streamingSlice.hasActiveStreaming;
  List<String> get streamingSessionIds => _streamingSlice.streamingSessionIds;
  List<String> get initiatingStreamingSessionIds =>
      _streamingSlice.initiatingSessionIds;

  bool get isSelectedSessionStreaming {
    final id = selectedSessionId;
    return id != null && _streamingSlice.isStreaming(id);
  }

  String? get selectedSessionStreamingText {
    final id = selectedSessionId;
    return id != null ? _streamingSlice.getStreamingText(id) : null;
  }

  bool get isSelectedSessionAwaitingResponse {
    final id = selectedSessionId;
    return isCreatingSession ||
        (id != null && _streamingSlice.isInitiating(id));
  }

  bool isSessionBusy(String sessionId) => _streamingSlice.isBusy(sessionId);

  SessionStreamingState getSessionStreamingState(String sessionId) =>
      _streamingSlice.getState(sessionId);

  // ============================================================
  // SESSIONS OPERATIONS
  // ============================================================
  Future<void> fetchSessions() => _sessionsSlice.fetch();

  Future<bool> deleteSession(String sessionId) =>
      _sessionsSlice.delete(sessionId);

  // ============================================================
  // SELECTED SESSION OPERATIONS
  // ============================================================
  void setSelectedSessionId(String sessionId) {
    _selectedSessionSlice.select(sessionId);
    _syncStreamingState();
  }

  Future<bool> fetchSelectedSessionMessages() async {
    final isStreaming =
        selectedSessionId != null &&
        _streamingSlice.isStreaming(selectedSessionId!);

    final success = await _selectedSessionSlice.fetchMessages();

    if (success) {
      // Sync loading message state based on whether we were awaiting response
      if (isSelectedSessionAwaitingResponse) {
        _selectedSessionSlice.addLoadingMessage();
      } else {
        _selectedSessionSlice.removeLoadingMessage();
      }

      // Sync streaming state if actively streaming
      if (isStreaming) {
        _syncStreamingState();
      }
    }

    return success;
  }

  void initializeNewSession(File? imageFile, RemoteImage? remoteImage) {
    _selectedSessionSlice.initializeNew(imageFile, remoteImage);
  }

  Future<String?> createSession() async {
    _stateSlices[ManagerStateSliceName.createSession] =
        ActionState<void>.loading();
    _selectedSessionSlice.addLoadingMessage();
    notifyListeners();

    final sessionId = await _selectedSessionSlice.create();

    if (sessionId != null) {
      _stateSlices[ManagerStateSliceName.createSession] =
          ActionState<void>.success(null);
      notifyListeners();

      _sessionsSlice.fetch();
      await _startStreaming(sessionId, contextMode: ContextMode.all);
    } else {
      _stateSlices[ManagerStateSliceName.createSession] =
          ActionState<void>.error('Failed to create session');
      _selectedSessionSlice.removeLoadingMessage();
      notifyListeners();
    }

    return sessionId;
  }

  Future<void> addMessageToSelectedSession(ChatMessage message) async {
    _selectedSessionSlice.addMessage(message);

    _stateSlices[ManagerStateSliceName.addMessageToSession] =
        ActionState<void>.loading();
    _selectedSessionSlice.addLoadingMessage();
    notifyListeners();

    final success = await _selectedSessionSlice.addMessageRemote(message);

    if (success) {
      _stateSlices[ManagerStateSliceName.addMessageToSession] =
          ActionState<void>.success(null);
      notifyListeners();

      final id = selectedSessionId;
      if (id != null) {
        await _startStreaming(id, contextMode: ContextMode.recent);
      }
    } else {
      _stateSlices[ManagerStateSliceName.addMessageToSession] =
          ActionState<void>.error('Failed to add message');
      _selectedSessionSlice.removeLoadingMessage();
      notifyListeners();
    }
  }

  void addToSelectedSessionMessages(ChatMessage message) {
    _selectedSessionSlice.addMessage(message);
  }

  void disposeSelectedSession({String? messageInputText}) {
    _selectedSessionSlice.dispose(draftText: messageInputText);
    _selectedSessionSlice.clear();
  }

  // ============================================================
  // STREAMING OPERATIONS
  // ============================================================
  Future<void> _startStreaming(
    String sessionId, {
    required ContextMode contextMode,
  }) async {
    await _streamingSlice.startStreaming(
      sessionId: sessionId,
      contextMode: contextMode,
      onInitiating: () {
        // Loading message already added
      },
      onStreamStarted: (id, text) {
        if (_selectedSessionSlice.sessionId == id) {
          _selectedSessionSlice.removeLoadingMessage();
          _selectedSessionSlice.addMessage(
            ChatMessage(isUser: false, text: text, timestamp: DateTime.now()),
          );
        }
      },
      onChunk: (id, text) {
        if (_selectedSessionSlice.sessionId == id) {
          _selectedSessionSlice.replaceLastBotMessage(text);
        }
      },
      onCompleted: (id, finalText) {
        if (_selectedSessionSlice.sessionId == id) {
          _selectedSessionSlice.replaceLastBotMessage(finalText);
          _selectedSessionSlice.removeLoadingMessage();
        }
      },
      onError: (id, error) {
        if (_selectedSessionSlice.sessionId == id) {
          _selectedSessionSlice.removeLoadingMessage();
        }
      },
    );
  }

  void _syncStreamingState() {
    final id = selectedSessionId;
    if (id == null) return;

    final state = _streamingSlice.getState(id);
    if (!state.isStreaming || state.streamingText.isEmpty) return;

    final messages = _selectedSessionSlice.messages;

    if (messages.isEmpty) {
      _selectedSessionSlice.addMessage(
        ChatMessage(
          isUser: false,
          text: state.streamingText,
          timestamp: DateTime.now(),
        ),
      );
    } else if (messages.last.isLoading) {
      _selectedSessionSlice.removeLoadingMessage();
      _selectedSessionSlice.addMessage(
        ChatMessage(
          isUser: false,
          text: state.streamingText,
          timestamp: DateTime.now(),
        ),
      );
    } else if (!messages.last.isUser) {
      _selectedSessionSlice.replaceLastBotMessage(state.streamingText);
    } else {
      _selectedSessionSlice.addMessage(
        ChatMessage(
          isUser: false,
          text: state.streamingText,
          timestamp: DateTime.now(),
        ),
      );
    }
  }
}
