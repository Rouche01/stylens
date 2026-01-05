import 'package:flutter/material.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import 'package:stylens_app/core/managers/style_analysis_session/index.dart';
import 'package:stylens_app/models/remote_image.dart';
import 'package:stylens_app/widgets/error_display.dart';
import 'package:stylens_app/widgets/message_bubble.dart';
import 'package:stylens_app/widgets/message_input.dart';
import 'package:stylens_app/models/chat_message.dart';

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
  late StyleAnalysisSessionManager sessionManager;

  @override
  void initState() {
    super.initState();

    sessionManager = context.read<StyleAnalysisSessionManager>();
    final selectedSessionId = sessionManager.selectedSessionId;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Load existing session if editing from history
      if (selectedSessionId != null) {
        _loadSessionData();
        return;
      }
      // Start new session if coming from image upload
      else if (widget.outfitImageFile != null) {
        sessionManager.initializeNewSession(
          widget.outfitImageFile,
          widget.remoteImage,
        );
      }
    });
  }

  void _scrollToBottomIfNeeded() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      const threshold = 100.0;
      final currentScroll = _scrollController.position.pixels;

      final maxScroll = _scrollController.position.maxScrollExtent;
      final minScroll = _scrollController.position.minScrollExtent;

      if (maxScroll - currentScroll <= threshold) {
        _scrollController.animateTo(
          maxScroll,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } else if (maxScroll > minScroll) {
        _scrollController.jumpTo(maxScroll);
        Future.delayed(const Duration(milliseconds: 100), () {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(
              _scrollController.position.maxScrollExtent,
            );
          }
        });
      }
    });
  }

  Future<void> _loadSessionData() async {
    final draftText = sessionManager.selectedSessionDraftText;
    _messageController.text = draftText ?? '';
    try {
      await sessionManager.fetchSelectedSessionMessages();

      // After loading, check streaming state
      final shouldResumeStreaming =
          sessionManager.isSelectedSessionStreaming &&
          sessionManager.selectedSessionStreamingText?.isNotEmpty == true;

      if (shouldResumeStreaming) {
        print(
          'Resuming streaming for session ${sessionManager.selectedSessionId} ${sessionManager.selectedSessionStreamingText}',
        );
      }
    } catch (e) {
      // Error is already set in the session manager
      print('Error loading session: $e');
    }
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final newUserMessage = ChatMessage(
      isUser: true,
      text: _messageController.text.trim(),
      timestamp: DateTime.now(),
    );
    final sessionManager = context.read<StyleAnalysisSessionManager>();
    final selectedSessionId = sessionManager.selectedSessionId;

    // If session hasn't been created remotely, create it now
    if (selectedSessionId == null && widget.outfitImageFile != null) {
      // Add user message to local state
      sessionManager.addToSelectedSessionMessages(newUserMessage);
      _messageController.clear();

      await sessionManager.createSession();
      return;
    }

    _messageController.clear();

    sessionManager.addMessageToSelectedSession(newUserMessage);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
      ),
      body: Selector<StyleAnalysisSessionManager, List<ChatMessage>>(
        selector: (context, sessionManager) =>
            sessionManager.selectedSessionMessages,
        builder: (context, messages, child) {
          final sessionManager = context.watch<StyleAnalysisSessionManager>();

          if (sessionManager.isSelectedSessionLoading) {
            return Center(child: CircularProgressIndicator());
          }

          // Show error UI if there's an error
          if (sessionManager.selectedSessionError != null &&
              sessionManager.selectedSessionId != null) {
            return ErrorDisplay(
              title: 'Failed to load session',
              message: sessionManager.selectedSessionError!,
              onRetry: () => _loadSessionData(),
            );
          }

          if (messages.isNotEmpty) {
            _scrollToBottomIfNeeded();
          }

          final isSendDisabled =
              sessionManager.isSelectedSessionAwaitingResponse ||
              sessionManager.isSelectedSessionStreaming;

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    return MessageBubble(message: messages[index]);
                  },
                ),
              ),
              MessageInput(
                messageController: _messageController,
                onSendMessage: _sendMessage,
                isSendDisabled: isSendDisabled,
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final draftText = _messageController.text.trim();
      sessionManager.disposeSelectedSession(messageInputText: draftText);
    });
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
