import 'dart:io';

import 'package:stylens_app/core/services/style_analysis_api_service.dart';
import 'package:stylens_app/models/action_state.dart';
import 'package:stylens_app/models/chat_message.dart';
import 'package:stylens_app/models/remote_image.dart';
import 'package:stylens_app/models/selected_session.dart';
import 'package:stylens_app/models/session_ui_state.dart';

/// Manages operations for the currently selected session
/// State is stored in the parent manager's _stateSlices map
class SelectedSessionSlice {
  final StyleAnalysisApiService _apiService;
  final ActionState<SelectedStyleAnalysisSession> Function() _getState;
  final void Function(ActionState<SelectedStyleAnalysisSession>) _setState;
  final void Function() _notifyListeners;

  SelectedSessionSlice({
    required StyleAnalysisApiService apiService,
    required ActionState<SelectedStyleAnalysisSession> Function() getState,
    required void Function(ActionState<SelectedStyleAnalysisSession>) setState,
    required void Function() notifyListeners,
  }) : _apiService = apiService,
       _getState = getState,
       _setState = setState,
       _notifyListeners = notifyListeners;

  static const _initialPrompt = 'What do you think about my outfit?';
  static const _initialBotReply =
      "Looking great! 🔥 What's the occasion for this outfit?";

  // --- UI State (kept locally in slice) ---
  final Map<String, SessionUIState> _uiStates = {};

  // --- Getters ---
  SelectedStyleAnalysisSession? get session => _getState().data;
  String? get sessionId => session?.sessionId;
  List<ChatMessage> get messages => session?.messages ?? [];
  bool get isLoading => _getState().isLoading;
  String? get error => _getState().error;

  String? get draftText {
    final id = sessionId;
    return id != null ? _uiStates[id]?.draftText : null;
  }

  // --- Selection ---
  void select(String sessionId) {
    _setState(
      ActionState.success(
        SelectedStyleAnalysisSession(sessionId: sessionId, messages: []),
      ),
    );
    _notifyListeners();
  }

  void clear() {
    _setState(ActionState.initial());
    _notifyListeners();
  }

  // --- Fetch Messages ---
  Future<bool> fetchMessages() async {
    final id = sessionId;
    if (id == null) {
      _setState(ActionState.error('No session selected'));
      _notifyListeners();
      return false;
    }

    _setState(ActionState.loading());
    _notifyListeners();

    final response = await _apiService.fetchSessionMessages(id);

    if (response.isSuccess && response.data != null) {
      _setState(
        ActionState.success(
          SelectedStyleAnalysisSession.fromJson({
            'session_id': id,
            'messages': response.data,
          }),
        ),
      );

      _notifyListeners();
      return true;
    }

    _setState(ActionState.error(response.error ?? 'Failed to load messages'));
    _notifyListeners();
    return false;
  }

  // --- Create Session ---
  Future<String?> create() async {
    final messageEntries = messages
        .map(
          (msg) => {
            'role': msg.isUser ? 'user' : 'system',
            'prompt': msg.text,
            'remoteImage': msg.remoteImage != null
                ? {'url': msg.remoteImage!.url, 'key': msg.remoteImage!.key}
                : null,
          },
        )
        .toList();

    final response = await _apiService.createSession(messages: messageEntries);

    if (response.isSuccess && response.data != null) {
      final newId = response.data!;
      _setState(
        ActionState.success(
          SelectedStyleAnalysisSession(sessionId: newId, messages: messages),
        ),
      );
      _notifyListeners();
      return newId;
    }

    return null;
  }

  // --- Add Message to Server ---
  Future<bool> addMessageRemote(ChatMessage message) async {
    final id = sessionId;
    if (id == null) return false;

    final response = await _apiService.addMessageToSession(
      sessionId: id,
      message: {
        'role': message.isUser ? 'user' : 'system',
        'prompt': message.text,
        'remoteImage': message.remoteImage != null
            ? {'url': message.remoteImage!.url, 'key': message.remoteImage!.key}
            : null,
      },
    );

    return response.isSuccess;
  }

  // --- Initialize New Session ---
  void initializeNew(File? imageFile, RemoteImage? remoteImage) {
    addMessage(
      ChatMessage(
        isUser: true,
        timestamp: DateTime.now(),
        imageFile: imageFile,
        remoteImage: remoteImage,
        text: _initialPrompt,
      ),
    );

    addMessage(
      ChatMessage(
        isUser: false,
        timestamp: DateTime.now(),
        text: _initialBotReply,
      ),
    );
  }

  // --- Message Operations ---
  void addMessage(ChatMessage message) {
    _setState(
      ActionState.success(
        SelectedStyleAnalysisSession(
          sessionId: sessionId,
          messages: [...messages, message],
        ),
      ),
    );
    _notifyListeners();
  }

  void replaceLastBotMessage(String text) {
    final currentMessages = messages;

    if (currentMessages.isEmpty || currentMessages.last.isUser) {
      addMessage(
        ChatMessage(isUser: false, text: text, timestamp: DateTime.now()),
      );
      return;
    }

    final lastMessage = currentMessages.last;
    _setState(
      ActionState.success(
        SelectedStyleAnalysisSession(
          sessionId: sessionId,
          messages: [
            ...currentMessages.sublist(0, currentMessages.length - 1),
            ChatMessage(
              isUser: false,
              text: text,
              timestamp: lastMessage.timestamp,
            ),
          ],
        ),
      ),
    );
    _notifyListeners();
  }

  void addLoadingMessage() {
    if (messages.isNotEmpty && messages.last.isLoading) return;
    addMessage(
      ChatMessage(isUser: false, isLoading: true, timestamp: DateTime.now()),
    );
  }

  void removeLoadingMessage() {
    if (messages.isNotEmpty && messages.last.isLoading) {
      _setState(
        ActionState.success(
          SelectedStyleAnalysisSession(
            sessionId: sessionId,
            messages: messages.sublist(0, messages.length - 1),
          ),
        ),
      );
      _notifyListeners();
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
