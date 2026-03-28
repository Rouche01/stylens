import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gostylens/core/managers/subscription_manager.dart';
import 'package:gostylens/core/config/dependency_injection.dart';
import 'package:gostylens/core/services/api_service/index.dart';
import 'package:gostylens/models/action_state.dart';
import 'package:gostylens/models/style_analysis_session_message.dart';
import 'package:gostylens/models/style_analysis_session_message_error.dart';
import 'package:gostylens/models/remote_image.dart';
import 'package:gostylens/models/selected_session.dart';
import 'package:gostylens/models/session_streaming_state.dart';
import 'package:gostylens/models/style_analysis_session.dart';

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
  // --- API Service ---
  late final StyleAnalysisApiService _apiService;

  // --- Error Callbacks ---
  void Function(String message)? onStreamError;

  // --- Sync Callbacks ---

  // --- State Slices (unified storage) ---
  final Map<ManagerStateSliceName, ActionState<dynamic>> _stateSlices = {
    ManagerStateSliceName.sessions: ActionState<List<StyleAnalysisSession>>(),
    ManagerStateSliceName.selectedSession:
        ActionState<SelectedStyleAnalysisSession>(),
    ManagerStateSliceName.createSession: ActionState<void>(),
    ManagerStateSliceName.addMessageToSession: ActionState<void>(),
    ManagerStateSliceName.deleteSession: ActionState<void>(),
  };

  Map<MessageErrorType, void Function()> get _errorCallbacks => {
    MessageErrorType.failedFetch: fetchSelectedSessionMessages,
  };

  // --- Slice Managers ---
  late final SessionsSlice _sessionsSlice;
  late final SelectedSessionSlice _selectedSessionSlice;
  late final SessionStreamingSlice _streamingSlice;

  StyleAnalysisSessionManager() {
    _apiService = locator<StyleAnalysisApiService>();

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
  bool get isLoadingMoreSessions => _sessionsSlice.isLoadingMore;
  bool get hasMoreSessions => _sessionsSlice.hasMore;
  int get totalCount => _sessionsSlice.totalCount;
  String? get sessionsError => _sessionsSlice.error;

  // ============================================================
  // SELECTED SESSION - Getters
  // ============================================================
  String? get selectedSessionId => _selectedSessionSlice.sessionId;
  List<StyleAnalysisSessionMessage> get selectedSessionMessages =>
      _selectedSessionSlice.messages;
  bool get isSelectedSessionLoading => _selectedSessionSlice.isLoading;
  bool get isLoadingMoreMessages => _selectedSessionSlice.isLoadingMoreMessages;
  bool get hasMoreMessages => _selectedSessionSlice.hasMoreMessages;
  String? get selectedSessionError => _selectedSessionSlice.error;
  String? get selectedSessionDraftText => _selectedSessionSlice.draftText;

  StyleAnalysisSession? get selectedSession {
    final id = selectedSessionId;
    if (id == null) return null;
    try {
      return sessions.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  bool get isCreatingSession =>
      (_stateSlices[ManagerStateSliceName.createSession] as ActionState<void>)
          .isLoading;
  String? get createSessionError =>
      (_stateSlices[ManagerStateSliceName.createSession] as ActionState<void>)
          .error;

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
  Future<void> fetchSessions({bool refresh = false, bool? isFavourite}) =>
      _sessionsSlice.fetch(refresh: refresh, isFavourite: isFavourite);

  Future<void> loadMoreSessions() => _sessionsSlice.loadMore();

  Future<bool> deleteSession(String sessionId) =>
      _sessionsSlice.delete(sessionId);

  Future<bool> toggleFavorite(
    String sessionId,
    bool isFavorite, {
    void Function(String error)? onError,
  }) => _sessionsSlice.toggleFavorite(sessionId, isFavorite, onError: onError);

  Future<bool> renameSession(
    String sessionId,
    String title, {
    void Function(String error)? onError,
  }) => _sessionsSlice.renameSession(sessionId, title, onError: onError);

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

  Future<bool> loadMoreMessages() async {
    return await _selectedSessionSlice.loadMoreMessages();
  }

  void clearOperationErrors() {
    _stateSlices[ManagerStateSliceName.createSession] =
        ActionState<void>.initial();
    _stateSlices[ManagerStateSliceName.addMessageToSession] =
        ActionState<void>.initial();
    notifyListeners();
  }

  Future<void> processInitialOutfit(
    List<File> files,
    List<RemoteImage> remoteImages,
  ) async {
    await _selectedSessionSlice.processInitialOutfit(files, remoteImages);
    notifyListeners();
  }

  Future<void> initializeNewSession(
    List<File>? imageFiles,
    List<RemoteImage>? remoteImages,
  ) async {
    clearOperationErrors();
    await _selectedSessionSlice.initializeNew(imageFiles, remoteImages);
  }

  Future<String?> createSession() async {
    _stateSlices[ManagerStateSliceName.createSession] =
        ActionState<void>.loading();
    _selectedSessionSlice.addLoadingMessage();
    notifyListeners();

    final sessionId = await _selectedSessionSlice.create((message) {
      _stateSlices[ManagerStateSliceName.createSession] =
          ActionState<void>.error(message);
    });

    if (sessionId != null) {
      _stateSlices[ManagerStateSliceName.createSession] =
          ActionState<void>.success(null);
      notifyListeners();

      _sessionsSlice.fetch();

      // Delay briefly to allow backend to update usage limits, then sync subscription
      Future.delayed(const Duration(seconds: 2), () {
        locator<SubscriptionManager>().syncSubscription();
      });

      await _startStreaming(sessionId, contextMode: ContextMode.all);
    } else {
      _selectedSessionSlice.replaceLoadingWithError(
        StyleAnalysisSessionMessageError.fromRawError(
          createSessionError ??
              'Unable to initiate styling session. Please try again.',
          null,
        ),
      );
      notifyListeners();
    }

    return sessionId;
  }

  Future<void> addMessageToSelectedSession(
    UserRole userRole, {
    String? text,
    List<File>? imageFiles,
    List<RemoteImage>? remoteImages,
    isLoading = false,
  }) async {
    _selectedSessionSlice.addMessage(
      userRole,
      text: text,
      imageFiles: imageFiles,
      remoteImages: remoteImages,
      isLoading: isLoading,
    );

    _stateSlices[ManagerStateSliceName.addMessageToSession] =
        ActionState<void>.loading();
    _selectedSessionSlice.addLoadingMessage();
    notifyListeners();

    final success = await _selectedSessionSlice.addMessageRemote(
      userRole,
      text: text,
      remoteImages: remoteImages,
    );

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
      _selectedSessionSlice.replaceLoadingWithError(
        StyleAnalysisSessionMessageError(
          message: 'Failed to send message. Please try again.',
        ),
      );
      notifyListeners();
    }
  }

  void removeErrorMessageFromSelectedSession() {
    _selectedSessionSlice.removeErrorMessage();
    notifyListeners();
  }

  Future<void> retryLastFailedAction({MessageErrorType? errorType}) async {
    removeErrorMessageFromSelectedSession();
    final id = selectedSessionId;

    if (errorType != null && _errorCallbacks[errorType] != null) {
      _errorCallbacks[errorType]!.call();
      return;
    }

    if (id == null) {
      // It was a createSession failure
      await createSession();
    } else {
      // It was an addMessage remote failure
      final messages = selectedSessionMessages;
      if (messages.isEmpty) return;

      final lastUserMsg = messages.firstWhere((m) => m.isUserMessage);

      _stateSlices[ManagerStateSliceName.addMessageToSession] =
          ActionState<void>.loading();
      _selectedSessionSlice.addLoadingMessage();
      notifyListeners();

      final success = await _selectedSessionSlice.addMessageRemote(
        UserRole.user,
        text: lastUserMsg.text,
        remoteImages: lastUserMsg.remoteImages,
      );

      if (success) {
        _stateSlices[ManagerStateSliceName.addMessageToSession] =
            ActionState<void>.success(null);
        notifyListeners();

        await _startStreaming(id, contextMode: ContextMode.recent);
      } else {
        _stateSlices[ManagerStateSliceName.addMessageToSession] =
            ActionState<void>.error('Failed to add message');
        _selectedSessionSlice.replaceLoadingWithError(
          StyleAnalysisSessionMessageError(
            message: 'Failed to send message. Please try again.',
          ),
        );
        notifyListeners();
      }
    }
  }

  void addToSelectedSessionMessages(
    UserRole userRole, {
    String? text,
    List<File>? imageFiles,
    List<RemoteImage>? remoteImages,
    isLoading = false,
  }) {
    _selectedSessionSlice.addMessage(
      userRole,
      text: text,
      imageFiles: imageFiles,
      remoteImages: remoteImages,
      isLoading: isLoading,
    );
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
          _selectedSessionSlice.addMessage(UserRole.assistant, text: text);
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
          onStreamError?.call(error);
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
        UserRole.assistant,
        text: state.streamingText,
      );
    } else if (messages.last.isLoading) {
      _selectedSessionSlice.removeLoadingMessage();
      _selectedSessionSlice.addMessage(
        UserRole.assistant,
        text: state.streamingText,
      );
    } else if (!messages.last.isUserMessage) {
      _selectedSessionSlice.replaceLastBotMessage(state.streamingText);
    } else {
      _selectedSessionSlice.addMessage(
        UserRole.assistant,
        text: state.streamingText,
      );
    }
  }
}
