import 'package:flutter/material.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import 'package:gostylens/core/managers/style_analysis_session/index.dart';
import 'package:gostylens/models/remote_image.dart';
import 'package:gostylens/widgets/error_display.dart';
import 'package:gostylens/widgets/message_bubble.dart';
import 'package:gostylens/widgets/message_input.dart';
import 'package:gostylens/models/style_analysis_session_message.dart';

class StyleAnalysisPage extends StatefulWidget {
  final File? outfitImageFile;
  final RemoteImage? remoteImage;

  const StyleAnalysisPage({super.key, this.outfitImageFile, this.remoteImage});

  @override
  State<StyleAnalysisPage> createState() => _StyleAnalysisPageState();
}

class _StyleAnalysisPageState extends State<StyleAnalysisPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();
  late StyleAnalysisSessionManager _sessionManager;

  static const double _loadMoreThreshold = 200.0;

  @override
  void initState() {
    super.initState();
    _sessionManager = context.read<StyleAnalysisSessionManager>();

    _sessionManager.onStreamError = _showErrorSnackBar;

    _scrollController.addListener(_onScroll);
    _initializeSession();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _inputFocusNode.dispose();
    _saveStateAndDispose();
    _messageController.dispose();
    super.dispose();
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 10),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  // ============================================================
  // INITIALIZATION
  // ============================================================

  void _initializeSession() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final selectedSessionId = _sessionManager.selectedSessionId;

      if (selectedSessionId != null) {
        _loadExistingSession();
      } else if (widget.outfitImageFile != null) {
        _sessionManager.initializeNewSession(
          widget.outfitImageFile,
          widget.remoteImage,
        );
      }

      _focusInput();
    });
  }

  void _focusInput() {
    // Delay to ensure TextField is mounted and ready
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted && _inputFocusNode.canRequestFocus) {
        _inputFocusNode.requestFocus();
      }
    });
  }

  Future<void> _loadExistingSession() async {
    final draftText = _sessionManager.selectedSessionDraftText;
    if (draftText != null && draftText.isNotEmpty) {
      _messageController.text = draftText;
    }

    try {
      await _sessionManager.fetchSelectedSessionMessages();
      _focusInput();
    } catch (e) {
      debugPrint('Error loading session: $e');
    }
  }

  void _saveStateAndDispose() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final draftText = _messageController.text.trim();
      _sessionManager.disposeSelectedSession(messageInputText: draftText);
    });
  }

  // ============================================================
  // SCROLL & PAGINATION
  // ============================================================

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;

    // In reversed list, maxScrollExtent is at the TOP (older messages)
    if (maxScroll - currentScroll <= _loadMoreThreshold) {
      _loadMoreMessages();
    }
  }

  Future<void> _loadMoreMessages() async {
    if (_sessionManager.isLoadingMoreMessages) return;
    if (!_sessionManager.hasMoreMessages) return;

    await _sessionManager.loadMoreMessages();
  }

  // ============================================================
  // MESSAGE HANDLING
  // ============================================================

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final selectedSessionId = _sessionManager.selectedSessionId;
    _messageController.clear();

    if (selectedSessionId == null && widget.outfitImageFile != null) {
      _sessionManager.addToSelectedSessionMessages(UserRole.user, text: text);
      await _sessionManager.createSession();
    } else {
      _sessionManager.addMessageToSelectedSession(UserRole.user, text: text);
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: _buildAppBar(), body: _buildBody());
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: Row(
        children: [
          Text(
            'GoStylens',
            style: TextStyle(
              fontFamily: 'ClashDisplay',
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSecondary,
            ),
          ),
        ],
      ),
      titleSpacing: 0,
      backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      leading: IconButton(
        icon: Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildBody() {
    return Consumer<StyleAnalysisSessionManager>(
      builder: (context, sessionManager, child) {
        if (sessionManager.isSelectedSessionLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (sessionManager.selectedSessionError != null &&
            sessionManager.selectedSessionId != null) {
          return ErrorDisplay(
            title: 'Failed to load session',
            message: sessionManager.selectedSessionError!,
            onRetry: _loadExistingSession,
          );
        }

        return _buildChatInterface(sessionManager);
      },
    );
  }

  Widget _buildChatInterface(StyleAnalysisSessionManager sessionManager) {
    final messages = sessionManager.selectedSessionMessages;
    final isSendDisabled =
        sessionManager.isSelectedSessionAwaitingResponse ||
        sessionManager.isSelectedSessionStreaming;

    return Column(
      children: [
        Expanded(child: _buildMessageList(sessionManager, messages)),
        MessageInput(
          messageController: _messageController,
          onSendMessage: _sendMessage,
          isSendDisabled: isSendDisabled,
          focusNode: _inputFocusNode,
        ),
      ],
    );
  }

  Widget _buildMessageList(
    StyleAnalysisSessionManager sessionManager,
    List<StyleAnalysisSessionMessage> messages,
  ) {
    final itemCount =
        messages.length + (sessionManager.isLoadingMoreMessages ? 1 : 0);

    if (itemCount == 0) {
      return const Center(child: Text('No messages yet'));
    }

    return Align(
      alignment: Alignment.topCenter,
      child: ListView.builder(
        controller: _scrollController,
        reverse: true,
        shrinkWrap: true,
        padding: const EdgeInsets.all(16),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          if (sessionManager.isLoadingMoreMessages &&
              index == messages.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Center(
                child: SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }

          final message = messages[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: MessageBubble(message: message),
          );
        },
      ),
    );
  }
}
