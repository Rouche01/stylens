import 'dart:io';

import 'package:gostylens/constants/ux_messages.dart';
import 'package:gostylens/core/managers/slice_state_manager.dart';
import 'package:gostylens/core/services/api_service/index.dart';
import 'package:gostylens/models/action_state.dart';
import 'package:gostylens/models/api_responses/pagination_info.dart';
import 'package:gostylens/models/style_analysis_session_message.dart';
import 'package:gostylens/models/style_analysis_session_message_error.dart';
import 'package:gostylens/models/remote_image.dart';
import 'package:gostylens/models/selected_session.dart';
import 'package:gostylens/models/session_ui_state.dart';

/// Manages operations for the currently selected session
/// State is stored in the parent manager's _stateSlices map
class SelectedSessionSlice {
  final StyleAnalysisApiService _apiService;
  late final SliceStateManager<SelectedStyleAnalysisSession> _sliceStateManager;

  SelectedSessionSlice({
    required StyleAnalysisApiService apiService,
    required ActionState<SelectedStyleAnalysisSession> Function() getState,
    required void Function(ActionState<SelectedStyleAnalysisSession>) setState,
    required void Function() notifyListeners,
  }) : _apiService = apiService {
    _sliceStateManager = SliceStateManager(
      getState: getState,
      setState: setState,
      notifyListeners: notifyListeners,
    );
  }

  static const _initialPrompt = UxMessages.initialOutfitPromptTextAugmentation;
  static const _initialBotReply = UxMessages.initialStylistReply;

  // --- UI State (kept locally in slice) ---
  final Map<String, SessionUIState> _uiStates = {};

  // --- Pagination State ---
  PaginationInfo? _paginationInfo;
  bool _isLoadingMoreMessages = false;

  // --- Getters ---
  SelectedStyleAnalysisSession? get session => _sliceStateManager.data;
  String? get sessionId => session?.sessionId;
  List<StyleAnalysisSessionMessage> get messages => session?.messages ?? [];
  bool get isLoading => _sliceStateManager.isLoading;
  String? get error => _sliceStateManager.error;
  bool get isLoadingMoreMessages => _isLoadingMoreMessages;
  bool get hasMoreMessages => _paginationInfo?.hasNextPage ?? false;
  int get currentPage => _paginationInfo?.page ?? 1;

  String? get draftText {
    final id = sessionId;
    return id != null ? _uiStates[id]?.draftText : null;
  }

  // --- Selection ---
  void select(String sessionId) {
    _paginationInfo = null;
    _isLoadingMoreMessages = false;
    _sliceStateManager.setSuccess(
      SelectedStyleAnalysisSession(sessionId: sessionId, messages: []),
    );
  }

  void clear() {
    _paginationInfo = null;
    _isLoadingMoreMessages = false;
    _sliceStateManager.setInitial();
  }

  // --- Fetch Messages ---
  Future<bool> fetchMessages() async {
    final id = sessionId;
    if (id == null) {
      _sliceStateManager.setError('No session selected');
      return false;
    }

    final response = await _sliceStateManager.execute(
      action: () => _apiService.fetchSessionMessages(id),
      onSuccess: (response) {
        if (response.isSuccess && response.data != null) {
          _paginationInfo = response.data!.pagination;
          return SelectedStyleAnalysisSession(
            sessionId: id,
            messages: response.data!.items,
          );
        }
        throw Exception(response.error ?? 'Failed to load messages');
      },
      onError: (e) => 'Failed to load messages: $e',
    );

    return response != null;
  }

  // --- Load More Messages ---
  Future<bool> loadMoreMessages() async {
    final id = sessionId;
    if (id == null) return false;
    if (_isLoadingMoreMessages) return false;
    if (!hasMoreMessages) return false;

    _isLoadingMoreMessages = true;
    _sliceStateManager.notify();

    final existingMessages = messages;

    final response = await _sliceStateManager.execute(
      action: () => _apiService.fetchSessionMessages(id, page: currentPage + 1),
      setLoadingState: false, // Don't override main loading state
      onSuccess: (response) {
        if (response.isSuccess && response.data != null) {
          _paginationInfo = response.data!.pagination;
          final olderMessages = response.data!.items;

          return SelectedStyleAnalysisSession(
            sessionId: id,
            messages: [...existingMessages, ...olderMessages],
          );
        }
        throw Exception(response.error ?? 'Failed to load more messages');
      },
      onError: (e) => 'Failed to load more messages: $e',
    );

    _isLoadingMoreMessages = false;
    _sliceStateManager.notify();

    return response != null;
  }

  // --- Create Session ---
  Future<String?> create(void Function(String message)? onError) async {
    final currentMessages = messages;

    final sortedMessages = [...currentMessages]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final messageEntries = sortedMessages
        .where((msg) => msg.text != null || msg.remoteImage != null)
        .map(
          (msg) => {
            'role': msg.role.name,
            'prompt': msg.text,
            'remoteImage': msg.remoteImage != null
                ? {'url': msg.remoteImage!.url, 'key': msg.remoteImage!.key}
                : null,
          },
        )
        .toList();

    final response = await _sliceStateManager.execute(
      action: () => _apiService.createSession(messages: messageEntries),
      retainDataOnError: true, // Keep the UI messages array alive!
      setLoadingState: false, // Don't wipe the chat view entirely
      onSuccess: (response) {
        if (response.isSuccess && response.data != null) {
          return SelectedStyleAnalysisSession(
            sessionId: response.data!,
            messages: currentMessages,
          );
        }
        throw Exception(response.error ?? 'Failed to create session');
      },
      onError: (e) {
        onError?.call(e.toString());
        return e.toString();
      },
    );

    return response?.data;
  }

  // --- Add Message to Server ---
  Future<bool> addMessageRemote(
    UserRole userRole, {
    String? text,
    RemoteImage? remoteImage,
  }) async {
    final id = sessionId;
    if (id == null) return false;

    final response = await _sliceStateManager.execute(
      action: () => _apiService.addMessageToSession(
        sessionId: id,
        message: {
          'role': userRole.name,
          'prompt': text,
          'remoteImage': remoteImage != null
              ? {'url': remoteImage.url, 'key': remoteImage.key}
              : null,
        },
      ),
      setLoadingState: false, // Don't change main state
      retainDataOnError: true, // Keep the UI messages untouched!
      onSuccess: (response) {
        if (response.isSuccess) {
          // Return current session state unchanged
          return session!;
        }
        throw Exception(response.error ?? 'Failed to add message');
      },
      onError: (e) => 'Failed to add message: $e',
    );

    return response != null;
  }

  // --- Initialize New Session ---
  void initializeNew(File? imageFile, RemoteImage? remoteImage) {
    addMessage(
      UserRole.user,
      imageFile: imageFile,
      remoteImage: remoteImage,
      text: _initialPrompt,
    );

    addMessage(UserRole.assistant, text: _initialBotReply);
  }

  // --- Message Operations ---
  void addMessage(
    UserRole userRole, {
    String? text,
    File? imageFile,
    RemoteImage? remoteImage,
    bool isLoading = false,
    StyleAnalysisSessionMessageError? error,
  }) {
    final newMessage = StyleAnalysisSessionMessage(
      role: userRole,
      timestamp: DateTime.now(),
      imageFile: imageFile,
      remoteImage: remoteImage,
      text: text,
      isLoading: isLoading,
      error: error,
    );

    _sliceStateManager.setSuccess(
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
    _sliceStateManager.setSuccess(
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

  void addLoadingMessage() {
    if (messages.isNotEmpty && messages.first.isLoading) return;
    addMessage(UserRole.assistant, isLoading: true);
  }

  void removeLoadingMessage() {
    if (messages.isNotEmpty && messages.first.isLoading) {
      _sliceStateManager.setSuccess(
        SelectedStyleAnalysisSession(
          sessionId: sessionId,
          messages: messages.sublist(1),
        ),
      );
    }
  }

  void replaceLoadingWithError(StyleAnalysisSessionMessageError error) {
    if (messages.isNotEmpty && messages.first.isLoading) {
      _sliceStateManager.setSuccess(
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
      _sliceStateManager.setSuccess(
        SelectedStyleAnalysisSession(
          sessionId: sessionId,
          messages: messages.sublist(1),
        ),
      );
    }
  }

  // --- UI State ---
  void saveDraftText(String text) {
    final id = sessionId;
    if (id == null) return;
    _uiStates[id] = (_uiStates[id] ?? SessionUIState()).copyWith(
      draftText: text,
    );
  }

  void dispose({String? draftText}) {
    if (draftText != null) saveDraftText(draftText);
    clear();
  }
}
