import 'dart:io';

import 'package:gostylens/core/managers/slice_state_manager.dart';
import 'package:gostylens/core/services/api_service/index.dart';
import 'package:gostylens/models/action_state.dart';
import 'package:gostylens/models/style_analysis_session_message.dart';
import 'package:gostylens/models/style_analysis_session_message_error.dart';
import 'package:gostylens/models/app_image.dart';
import 'package:gostylens/models/selected_session.dart';
import 'package:gostylens/models/session_ui_state.dart';
import 'package:gostylens/core/managers/asset_upload_manager.dart';
import 'package:gostylens/core/managers/style_analysis_session/actions/selected_session_actions.dart';
import 'package:gostylens/core/managers/style_analysis_session/session_message_cache.dart';
import 'package:gostylens/constants/ux_messages.dart';

enum _PendingLocalIntro { none, empty, outfit }

/// Manages operations for the currently selected session
/// State is stored in the parent manager's _stateSlices map
class SelectedSessionSlice with SelectedSessionActions {
  @override
  final StyleAnalysisApiService apiService;
  @override
  final AssetApiService assetApiService;
  @override
  final AssetUploadManager assetUploadManager;
  @override
  late final SliceStateManager<SelectedStyleAnalysisSession> sliceStateManager;

  SelectedSessionSlice({
    required this.apiService,
    required this.assetApiService,
    required this.assetUploadManager,
    required ActionState<SelectedStyleAnalysisSession> Function() getState,
    required void Function(ActionState<SelectedStyleAnalysisSession>) setState,
    required void Function() notifyListeners,
  }) {
    sliceStateManager = SliceStateManager(
      getState: getState,
      setState: setState,
      notifyListeners: notifyListeners,
    );
  }

  // --- UI State (kept locally in slice) ---
  final Map<String, SessionUIState> _uiStates = {};
  final SessionMessageCache _messageCache = SessionMessageCache();

  /// Bumped when starting a new local session or releasing the active one so
  /// in-flight empty/outfit bootstrap delays cannot append to a later session.
  int _localBootstrapGeneration = 0;

  /// Set by [prepareEmptySession] / [prepareOutfitSession]; consumed by
  /// [playPendingLocalIntro] once the chat route is on screen.
  _PendingLocalIntro _pendingLocalIntro = _PendingLocalIntro.none;

  @override
  int get localBootstrapGeneration => _localBootstrapGeneration;

  @override
  int beginLocalSessionBootstrap() {
    _localBootstrapGeneration++;
    _pendingLocalIntro = _PendingLocalIntro.none;
    paginationInfo = null;
    isLoadingMoreMessages = false;
    _uiStates.remove('');
    sliceStateManager.setSuccess(
      SelectedStyleAnalysisSession(sessionId: null, messages: const []),
    );
    return _localBootstrapGeneration;
  }

  @override
  bool isLocalBootstrapCurrent(int generation) =>
      generation == _localBootstrapGeneration;

  void _invalidateLocalBootstrap() {
    _localBootstrapGeneration++;
    _pendingLocalIntro = _PendingLocalIntro.none;
  }

  /// Sync reset for a History FAB / empty-chat start. Call [playPendingLocalIntro]
  /// after navigating to `/session`.
  void prepareEmptySession() {
    beginLocalSessionBootstrap();
    _pendingLocalIntro = _PendingLocalIntro.empty;
    addLoadingMessage();
  }

  /// Sync reset + user outfit message for Capture. Call [playPendingLocalIntro]
  /// after navigating to `/session`.
  void prepareOutfitSession(List<AppImage> images) {
    beginLocalSessionBootstrap();
    _pendingLocalIntro = _PendingLocalIntro.outfit;
    addMessage(
      UserRole.user,
      images: images,
      text: UxMessages.initialOutfitPromptTextAugmentation,
    );
    addLoadingMessage();
  }

  /// Runs empty/outfit intro delays for a prepared local session. No-ops when
  /// nothing is pending or the bootstrap generation was invalidated.
  Future<void> playPendingLocalIntro() async {
    final generation = _localBootstrapGeneration;
    final pending = _pendingLocalIntro;
    _pendingLocalIntro = _PendingLocalIntro.none;

    switch (pending) {
      case _PendingLocalIntro.empty:
        await playEmptySessionIntro(generation);
      case _PendingLocalIntro.outfit:
        await playOutfitSessionIntro(generation);
      case _PendingLocalIntro.none:
        return;
    }
  }

  // --- Getters ---
  SelectedStyleAnalysisSession? get session => sliceStateManager.data;
  bool get isLoading => sliceStateManager.isLoading;
  String? get error => sliceStateManager.error;

  String? get draftText {
    final id = sessionId;
    return id != null ? _uiStates[id]?.draftText : null;
  }

  List<File> get attachedImageFiles {
    final id = sessionId;
    return id != null ? _uiStates[id]?.attachedImageFiles ?? [] : [];
  }

  @override
  bool hasCachedMessages(String sessionId) => _messageCache.contains(sessionId);

  /// Clears cached messages and per-session UI state (drafts, attachments).
  void clearMessageCache() {
    _messageCache.clear();
    _uiStates.clear();
  }

  // --- Selection ---
  void select(String sessionId) {
    if (this.sessionId == sessionId) {
      return;
    }

    _invalidateLocalBootstrap();
    isLoadingMoreMessages = false;
    final cached = _messageCache.get(sessionId);
    if (cached != null && cached.messages.isNotEmpty) {
      paginationInfo = cached.pagination;
      sliceStateManager.setSuccess(
        SelectedStyleAnalysisSession(
          sessionId: sessionId,
          messages: cached.messages,
        ),
      );
      return;
    }

    paginationInfo = null;
    sliceStateManager.setSuccess(
      SelectedStyleAnalysisSession(sessionId: sessionId, messages: []),
    );
  }

  void clear() {
    _invalidateLocalBootstrap();
    paginationInfo = null;
    isLoadingMoreMessages = false;
    sliceStateManager.setInitial();
  }

  void releaseActiveSession({String? draftText, bool notify = true}) {
    _invalidateLocalBootstrap();
    if (draftText != null) saveDraftText(draftText);
    persistMessageCache();
    paginationInfo = null;
    isLoadingMoreMessages = false;
    sliceStateManager.setInitial(notify: notify);
  }

  @override
  void persistMessageCache() {
    final id = sessionId;
    if (id == null || id.isEmpty) return;

    final currentMessages = messages.where((m) => !m.isLoading).toList();
    if (currentMessages.isEmpty) return;

    _messageCache.put(
      id,
      SessionMessageCacheEntry(
        messages: List<StyleAnalysisSessionMessage>.from(currentMessages),
        pagination: paginationInfo,
        cachedAt: DateTime.now(),
      ),
    );
  }

  void _setSessionSuccess(
    SelectedStyleAnalysisSession data, {
    bool notify = true,
  }) {
    sliceStateManager.setSuccess(data, notify: notify);
    persistMessageCache();
  }

  // --- Message Operations ---
  @override
  void addMessage(
    UserRole userRole, {
    String? text,
    List<AppImage>? images,
    bool isLoading = false,
    StyleAnalysisSessionMessageError? error,
  }) {
    final newMessage = StyleAnalysisSessionMessage(
      role: userRole,
      timestamp: DateTime.now(),
      images: images,
      text: text,
      isLoading: isLoading,
      error: error,
    );

    _setSessionSuccess(
      SelectedStyleAnalysisSession(
        sessionId: sessionId,
        messages: [newMessage, ...messages],
      ),
    );
  }

  void replaceLastBotMessage(String text) {
    final currentMessages = messages;

    if (currentMessages.isEmpty || currentMessages.first.isUserMessage) {
      addMessage(UserRole.assistant, text: text);
      return;
    }

    final firstMessage = currentMessages.first;
    _setSessionSuccess(
      SelectedStyleAnalysisSession(
        sessionId: sessionId,
        messages: [
          StyleAnalysisSessionMessage(
            role: UserRole.assistant,
            text: text,
            timestamp: firstMessage.timestamp,
          ),
          ...currentMessages.sublist(1),
        ],
      ),
    );
  }

  @override
  void addLoadingMessage() {
    if (messages.isNotEmpty && messages.first.isLoading) return;
    addMessage(UserRole.assistant, isLoading: true);
  }

  @override
  void removeLoadingMessage() {
    if (messages.isNotEmpty && messages.first.isLoading) {
      _setSessionSuccess(
        SelectedStyleAnalysisSession(
          sessionId: sessionId,
          messages: messages.sublist(1),
        ),
      );
    }
  }

  @override
  void replaceLoadingWithError(StyleAnalysisSessionMessageError error) {
    if (messages.isNotEmpty && messages.first.isLoading) {
      _setSessionSuccess(
        SelectedStyleAnalysisSession(
          sessionId: sessionId,
          messages: [
            StyleAnalysisSessionMessage(
              role: UserRole.assistant,
              timestamp: DateTime.now(),
              error: error,
            ),
            ...messages.sublist(1),
          ],
        ),
      );
    }
  }

  void removeErrorMessage() {
    if (messages.isNotEmpty && messages.first.isError) {
      _setSessionSuccess(
        SelectedStyleAnalysisSession(
          sessionId: sessionId,
          messages: messages.sublist(1),
        ),
      );
    }
  }

  @override
  void saveDraftText(String text) {
    final id = sessionId ?? '';
    _uiStates[id] = (_uiStates[id] ?? SessionUIState()).copyWith(
      draftText: text,
    );
  }

  void addAttachedImage(File file) {
    final id = sessionId ?? '';
    final currentState = _uiStates[id] ?? SessionUIState();
    final updatedFiles = [...currentState.attachedImageFiles, file];
    _uiStates[id] = currentState.copyWith(attachedImageFiles: updatedFiles);
    sliceStateManager.notify();
  }

  void removeAttachedImage(int index) {
    final id = sessionId ?? '';
    final currentState = _uiStates[id] ?? SessionUIState();
    if (index >= 0 && index < currentState.attachedImageFiles.length) {
      final updatedFiles = [...currentState.attachedImageFiles]
        ..removeAt(index);
      _uiStates[id] = currentState.copyWith(attachedImageFiles: updatedFiles);
      sliceStateManager.notify();
    }
  }

  @override
  void clearAttachedImages() {
    final id = sessionId ?? '';
    final currentState = _uiStates[id] ?? SessionUIState();
    _uiStates[id] = currentState.copyWith(attachedImageFiles: []);
    sliceStateManager.notify();
  }

  void dispose({String? draftText}) {
    releaseActiveSession(draftText: draftText);
  }
}
