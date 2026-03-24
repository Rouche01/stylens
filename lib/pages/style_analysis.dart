import 'package:flutter/material.dart';
import 'package:gostylens/constants/ux_messages.dart';
import 'package:gostylens/models/style_analysis_session_message_error.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import 'package:gostylens/core/managers/style_analysis_session/index.dart';
import 'package:gostylens/models/remote_image.dart';
import 'package:gostylens/widgets/error_display.dart';
import 'package:gostylens/widgets/message_bubble.dart';
import 'package:gostylens/widgets/message_input.dart';
import 'package:gostylens/models/style_analysis_session_message.dart';
import 'package:gostylens/widgets/session_actions_menu.dart';
import 'package:gostylens/pages/paywall.dart';
import 'package:image_picker/image_picker.dart';
import 'package:gostylens/core/managers/subscription_manager.dart';
import 'package:gostylens/core/services/api_service/index.dart';
import 'package:gostylens/core/managers/global_loader/index.dart';

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
  final ImagePicker _picker = ImagePicker();
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

  Future<void> _initializeSession() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _sessionManager.clearOperationErrors();
      final selectedSessionId = _sessionManager.selectedSessionId;

      if (selectedSessionId != null && selectedSessionId.isNotEmpty) {
        _loadExistingSession();
      } else if (widget.outfitImageFile != null) {
        await _sessionManager.initializeNewSession(
          widget.outfitImageFile,
          widget.remoteImage,
        );
      } else {
        await _sessionManager.initializeNewSession(null, null);
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
    } else if (selectedSessionId == '' || selectedSessionId == null) {
      _sessionManager.addToSelectedSessionMessages(UserRole.user, text: text);
      await _sessionManager.createSession();
    } else {
      _sessionManager.addMessageToSelectedSession(UserRole.user, text: text);
    }
  }

  // ============================================================
  // ATTACHMENT HANDLING
  // ============================================================

  Future<bool> _checkLimitsAndProceed() async {
    final subManager = context.read<SubscriptionManager>();

    if (subManager.subscription == null) {
      GlobalLoaderController.instance.show('Your stylist is getting ready...');
      try {
        await subManager.syncSubscription();
      } finally {
        GlobalLoaderController.instance.hide();
      }
    }

    final activeSub = subManager.subscription;

    if (activeSub == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to verify your plan. Please try again.'),
          ),
        );
      }
      return false;
    }

    if (!activeSub.isFree || !activeSub.hasReachedLimit) {
      return true;
    }

    if (!mounted) return false;

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const PaywallPage()),
    );

    return result == true;
  }

  Future<RemoteImage?> _uploadToR2(File imageFile, String filename) async {
    GlobalLoaderController.instance.show(UxMessages.uploadOutfitLoader);
    try {
      final assetApiService = AssetApiService();
      final responseData = await assetApiService.getUploadUrl(filename);

      final uploadUrl = responseData.uploadUrl;
      final downloadUrl = responseData.downloadUrl;
      final returnedFilename = responseData.filename;

      final imageFileBytes = await imageFile.readAsBytes();
      final statusCode = await assetApiService.uploadImage(
        uploadUrl,
        imageFileBytes,
      );

      if (statusCode == 200) {
        return RemoteImage(url: downloadUrl, key: returnedFilename);
      } else {
        debugPrint('❌ Upload failed: $statusCode');
        return null;
      }
    } catch (e) {
      GlobalLoaderController.instance.hide();
      rethrow;
    }
  }

  void _onAttachPressed() {
    final colorScheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colorScheme.tertiary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height / 3,
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: Icon(Icons.photo_camera, color: colorScheme.primary),
              title: Text(
                'Take Photo',
                style: TextStyle(color: colorScheme.primary),
              ),
              onTap: () {
                Navigator.pop(context);
                _handleImageCapture(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library, color: colorScheme.primary),
              title: Text(
                'Choose from Gallery',
                style: TextStyle(color: colorScheme.primary),
              ),
              onTap: () {
                Navigator.pop(context);
                _handleImageCapture(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleImageCapture(ImageSource source) async {
    final canProceed = await _checkLimitsAndProceed();
    if (!canProceed) return;

    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 85,
      );

      if (image != null) {
        final file = File(image.path);
        final remoteImage = await _uploadToR2(file, image.name);

        if (remoteImage != null && mounted) {
          final selectedSessionId = _sessionManager.selectedSessionId;
          if (selectedSessionId == null ||
              selectedSessionId.isEmpty ||
              _sessionManager.selectedSessionMessages.length <= 1) {
            // New session or just starting
            _sessionManager.initializeNewSession(file, remoteImage);
            await _sessionManager.createSession();
          } else {
            // Existing session
            await _sessionManager.addMessageToSelectedSession(
              UserRole.user,
              imageFile: file,
              remoteImage: remoteImage,
              text: UxMessages.initialOutfitPromptTextAugmentation,
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      GlobalLoaderController.instance.hide();
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: _buildAppBar(), body: _buildBody());
  }

  ErrorAction _buildMessageErrorAction(MessageErrorType messageErrorType) {
    if (messageErrorType == MessageErrorType.freeLimitReached) {
      return ErrorAction(
        label: 'Upgrade plan',
        labelStyle: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
          fontSize: 13,
          decoration: TextDecoration.underline,
        ),
        showIcon: false,
        handleAction: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            showDragHandle: true,
            backgroundColor: Theme.of(context).colorScheme.tertiary,
            barrierColor: Colors.black.withValues(
              alpha: 0.7,
            ), // Darker dimming instead of blur for native support
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            clipBehavior: Clip.antiAlias,
            builder: (context) => SizedBox(
              height: MediaQuery.of(context).size.height * 0.7,
              child: const PaywallPage(isDrawer: true),
            ),
          );
        },
      );
    }

    return ErrorAction(
      label: 'Retry',
      handleAction: () => _sessionManager.retryLastFailedAction(),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: Row(
        children: [Image.asset('assets/imgs/logo_primary.png', height: 24)],
      ),
      titleSpacing: 0,
      backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(context),
        color: Theme.of(context).colorScheme.primary,
      ),
      actions: [
        Consumer<StyleAnalysisSessionManager>(
          builder: (context, sessionManager, child) {
            final session = sessionManager.selectedSession;
            if (session == null) return const SizedBox.shrink();

            return SessionActionsMenu(
              session: session,
              position: PopupMenuPosition.under,
              iconColor: Theme.of(context).colorScheme.primary,
            );
          },
        ),
      ],
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
        sessionManager.isSelectedSessionStreaming ||
        sessionManager.createSessionError != null;

    final isTextFieldDisabled =
        sessionManager.createSessionError != null ||
        sessionManager.isCreatingSession;

    return Column(
      children: [
        Expanded(child: _buildMessageList(sessionManager, messages)),
        MessageInput(
          messageController: _messageController,
          onSendMessage: _sendMessage,
          isSendDisabled: isSendDisabled,
          isTextFieldDisabled: isTextFieldDisabled,
          focusNode: _inputFocusNode,
          placeholder: UxMessages.styleAnalysisChatInputPlaceholder,
          onAttachPressed: _onAttachPressed,
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
            child: MessageBubble(
              message: message,
              errorAction: message.error != null
                  ? _buildMessageErrorAction(message.error!.type)
                  : const ErrorAction(),
            ),
          );
        },
      ),
    );
  }
}
