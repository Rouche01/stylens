import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gostylens/core/managers/subscription_manager.dart';
import 'package:gostylens/core/config/dependency_injection.dart';
import 'package:gostylens/core/services/api_service/index.dart';
import 'package:gostylens/models/action_state.dart';
import 'package:gostylens/models/style_analysis_session_message.dart';
import 'package:gostylens/models/style_analysis_session_message_error.dart';
import 'package:gostylens/models/app_image.dart';
import 'package:gostylens/models/remote_image.dart';
import 'package:gostylens/models/selected_session.dart';
import 'package:gostylens/models/session_streaming_state.dart';
import 'package:gostylens/models/style_analysis_session.dart';

import 'slices/selected_session_slice.dart';
import 'slices/session_streaming_slice.dart';
import 'slices/sessions_slice.dart';
import 'package:gostylens/core/services/analytics_service.dart';
import 'package:gostylens/core/managers/asset_upload_manager.dart';

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
    MessageErrorType.streaming: () {
      final id = selectedSessionId;
      if (id != null) {
        _selectedSessionSlice.addLoadingMessage();
        _startStreaming(id, contextMode: ContextMode.recent);
      }
    },
  };

  String getErrorActionLabel(MessageErrorType type) {
    return switch (type) {
      MessageErrorType.streaming => 'Try again',
      MessageErrorType.freeLimitReached => 'Upgrade',
      _ => 'Retry',
    };
  }

  // --- Slice Managers ---
  late final SessionsSlice _sessionsSlice;
  late final SelectedSessionSlice _selectedSessionSlice;
  late final SessionStreamingSlice _streamingSlice;

  bool _sessionsListStale = false;

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
      assetApiService: locator<AssetApiService>(),
      assetUploadManager: locator<AssetUploadManager>(),
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

  bool get sessionsListStale => _sessionsListStale;

  void markSessionsListStale() {
    _sessionsListStale = true;
  }

  bool consumeSessionsListStale() {
    final wasStale = _sessionsListStale;
    _sessionsListStale = false;
    return wasStale;
  }

  void _onSessionsListActivity(String sessionId) {
    markSessionsListStale();
    final exists = sessions.any((s) => s.id == sessionId);
    if (exists) {
      _sessionsSlice.bumpSessionActivity(sessionId);
    } else {
      // New sessions are not in the list yet — bump is a no-op for unknown ids.
      // Refresh immediately so History (and selectedSession lookup) see the card.
      _sessionsSlice.refreshPreservingPagination(silent: true);
    }
  }

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
  Future<void> fetchSessions({
    bool forceRefresh = false,
    bool? isFavourite,
    bool silent = false,
  }) =>
      _sessionsSlice.fetch(
        forceRefresh: forceRefresh,
        isFavourite: isFavourite,
        silent: silent,
      );

  Future<void> refreshSessionsPreservingPagination({bool silent = true}) =>
      _sessionsSlice.refreshPreservingPagination(silent: silent);

  void bumpSessionActivity(String sessionId, {String? title}) =>
      _sessionsSlice.bumpSessionActivity(sessionId, title: title);

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

  bool hasCachedMessages(String sessionId) =>
      _selectedSessionSlice.hasCachedMessages(sessionId);

  void clearMessageCache() => _selectedSessionSlice.clearMessageCache();

  Future<bool> fetchSelectedSessionMessages({
    bool silent = false,
    bool forceRefresh = false,
  }) async {
    final isStreaming =
        selectedSessionId != null &&
        _streamingSlice.isStreaming(selectedSessionId!);

    final success = await _selectedSessionSlice.fetchMessages(
      silent: silent,
      forceRefresh: forceRefresh,
    );

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

  /// Sync: clear prior local chat and show a loading bubble. Navigate to
  /// `/session`, then call [playPendingLocalIntro].
  void prepareEmptySession() {
    clearOperationErrors();
    _selectedSessionSlice.prepareEmptySession();
    notifyListeners();
  }

  /// Sync: clear prior local chat and show the outfit user message. Navigate to
  /// `/session`, then call [playPendingLocalIntro].
  void prepareOutfitSession(List<AppImage> images) {
    clearOperationErrors();
    _selectedSessionSlice.prepareOutfitSession(images);
    notifyListeners();
  }

  /// Async intros for a session prepared via [prepareEmptySession] /
  /// [prepareOutfitSession]. Safe to call when nothing is pending.
  Future<void> playPendingLocalIntro() async {
    await _selectedSessionSlice.playPendingLocalIntro();
    notifyListeners();
  }

  Future<void> submitInitialOutfit(List<AppImage> images) async {
    await _selectedSessionSlice.submitInitialOutfit(images);
    notifyListeners();
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

      markSessionsListStale();
      await _sessionsSlice.refreshPreservingPagination(silent: true);

      // Delay briefly to allow backend to update usage limits, then sync subscription
      Future.delayed(const Duration(seconds: 2), () {
        locator<SubscriptionManager>().syncSubscription();
      });

      await _startStreaming(sessionId, contextMode: ContextMode.all);

      locator<AnalyticsService>().capture(
        'style_analysis_session_created',
        properties: {'session_id': sessionId},
      );
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
    List<AppImage>? images,
    isLoading = false,
  }) async {
    _selectedSessionSlice.addMessage(
      userRole,
      text: text,
      images: images,
      isLoading: isLoading,
    );

    _stateSlices[ManagerStateSliceName.addMessageToSession] =
        ActionState<void>.loading();
    _selectedSessionSlice.addLoadingMessage();
    notifyListeners();

    final success = await _selectedSessionSlice.addMessageRemote(
      userRole,
      text: text,
      remoteImages: images
          ?.map((i) => i.remoteImage)
          .whereType<RemoteImage>()
          .toList(),
    );

    if (success) {
      _stateSlices[ManagerStateSliceName.addMessageToSession] =
          ActionState<void>.success(null);
      notifyListeners();

      final id = selectedSessionId;
      if (id != null) {
        _onSessionsListActivity(id);
        await _startStreaming(id, contextMode: ContextMode.recent);
        locator<AnalyticsService>().capture(
          'message_sent',
          properties: {
            'session_id': id,
            'user_role': userRole.name,
            'has_text': text != null && text.isNotEmpty,
            'has_images': images != null && images.isNotEmpty,
          },
        );
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
    locator<AnalyticsService>().capture(
      'session_retry_tapped',
      properties: {
        'error_type': errorType?.name ?? 'unknown',
        'session_id': selectedSessionId ?? '',
      },
    );
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
        remoteImages: lastUserMsg.images
            ?.map((i) => i.remoteImage)
            .whereType<RemoteImage>()
            .toList(),
      );

      if (success) {
        _stateSlices[ManagerStateSliceName.addMessageToSession] =
            ActionState<void>.success(null);
        notifyListeners();

        _onSessionsListActivity(id);
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
    List<AppImage>? images,
    isLoading = false,
  }) {
    _selectedSessionSlice.addMessage(
      userRole,
      text: text,
      images: images,
      isLoading: isLoading,
    );
  }

  Future<void> sendMessage({
    required String text,
    required List<AppImage> images,
  }) async {
    await _selectedSessionSlice.sendMessage(
      text: text,
      images: images,
      startStreaming: _startStreaming,
      onSessionsListActivity: _onSessionsListActivity,
    );
  }

  List<File> get attachedImageFiles => _selectedSessionSlice.attachedImageFiles;

  void addAttachedImage(File file) =>
      _selectedSessionSlice.addAttachedImage(file);

  void removeAttachedImage(int index) =>
      _selectedSessionSlice.removeAttachedImage(index);

  void clearAttachedImages() => _selectedSessionSlice.clearAttachedImages();

  void disposeSelectedSession({String? messageInputText}) {
    _selectedSessionSlice.releaseActiveSession(draftText: messageInputText);
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
        // Bump for immediate reorder; refresh picks up server-generated title.
        markSessionsListStale();
        _sessionsSlice.bumpSessionActivity(id);
        _sessionsSlice.refreshPreservingPagination(silent: true);
      },
      onError: (id, error) {
        if (_selectedSessionSlice.sessionId == id) {
          _selectedSessionSlice.replaceLoadingWithError(
            StyleAnalysisSessionMessageError(
              message: error,
              type: MessageErrorType.streaming,
            ),
          );
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
