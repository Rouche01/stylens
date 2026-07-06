import 'package:flutter/material.dart';
import 'package:gostylens/constants/ux_messages.dart';
import 'package:gostylens/models/style_analysis_session_message_error.dart';
import 'package:gostylens/utils/style_analysis_actions.dart';
import 'package:gostylens/navigation/navigation_helpers.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import 'package:gostylens/core/managers/style_analysis_session/index.dart';
import 'package:gostylens/widgets/error_display.dart';
import 'package:gostylens/widgets/message_bubble.dart';
import 'package:gostylens/widgets/message_input.dart';
import 'package:gostylens/models/style_analysis_session_message.dart';
import 'package:gostylens/widgets/full_screen_image_preview.dart';
import 'package:gostylens/widgets/session_actions_menu.dart';
import 'package:gostylens/widgets/attachment_sheet.dart';
import 'package:gostylens/widgets/action_card.dart';
import 'package:gostylens/pages/paywall.dart';
import 'package:image_picker/image_picker.dart';
import 'package:gostylens/core/config/env_config.dart';
import 'package:gostylens/core/config/dependency_injection.dart';
import 'package:gostylens/core/managers/subscription_manager.dart';
import 'package:gostylens/core/managers/location_manager.dart';
import 'package:gostylens/models/app_image.dart';

class StyleAnalysisPage extends StatefulWidget {
  const StyleAnalysisPage({super.key});

  @override
  State<StyleAnalysisPage> createState() => _StyleAnalysisPageState();
}

class _StyleAnalysisPageState extends State<StyleAnalysisPage>
    with StyleAnalysisActions {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();
  final ImagePicker _picker = ImagePicker();
  late StyleAnalysisSessionManager _sessionManager;

  static const double _loadMoreThreshold = 200.0;

  bool get _isNewSession =>
      _sessionManager.selectedSessionId == null ||
      _sessionManager.selectedSessionId!.isEmpty;

  bool get _shouldShowInitialActionCard {
    final messages = _sessionManager.selectedSessionMessages;
    final hasUserImage = messages.any(
      (m) =>
          m.role == UserRole.user &&
          (m.images?.any((img) => img.remoteImage != null) ?? false),
    );

    return _isNewSession &&
        !hasUserImage &&
        _sessionManager.attachedImageFiles.isEmpty;
  }

  @override
  void initState() {
    super.initState();
    _sessionManager = context.read<StyleAnalysisSessionManager>();

    _scrollController.addListener(_onScroll);
    _initializeSession();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SubscriptionManager>().syncSubscription();
      if (_isNewSession) {
        _maybePromptForLocation();
      }
    });
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

  // ============================================================
  // INITIALIZATION
  // ============================================================

  Future<void> _initializeSession() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _sessionManager.clearOperationErrors();

      if (!_isNewSession) {
        _loadExistingSession();
      }

      if (_isNewSession && !_shouldShowInitialActionCard) {
        _focusInput(); // only pop keyboard for brand new chats
      }
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
    } catch (e) {
      debugPrint('Error loading session: $e');
    }
  }

  Future<void> _maybePromptForLocation() async {
    if (!EnvConfig.locationPermissionPromptEnabled) return;
    if (!mounted || !_isNewSession) return;

    final locationManager = locator<LocationManager>();
    if (await locationManager.hasShownExplainer()) return;
    if (!mounted) return;

    final allow = await _showStyledConfirmDialog(
      title: UxMessages.locationExplainerTitle,
      message: UxMessages.locationExplainerBody,
      cancelLabel: UxMessages.locationExplainerNotNow,
      confirmLabel: UxMessages.locationExplainerAllow,
    );

    if (!mounted) return;

    await locationManager.markExplainerShown(userDeclined: allow != true);

    if (allow != true) return;

    final result = await locationManager.ensureAccess();
    if (!mounted) return;

    switch (result) {
      case LocationAccessResult.deniedForever:
        await _showLocationDeniedForeverDialog();
      case LocationAccessResult.servicesDisabled:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(UxMessages.locationServicesDisabled)),
        );
      case LocationAccessResult.granted:
      case LocationAccessResult.denied:
      case LocationAccessResult.userPreviouslyDeclined:
        break;
    }
  }

  Future<void> _showLocationDeniedForeverDialog() async {
    final openSettings = await _showStyledConfirmDialog(
      title: UxMessages.locationDeniedForeverTitle,
      message: UxMessages.locationDeniedForeverBody,
      cancelLabel: UxMessages.locationExplainerNotNow,
      confirmLabel: UxMessages.locationOpenSettings,
    );

    if (openSettings == true) {
      await locator<LocationManager>().openSettings();
    }
  }

  Future<bool?> _showStyledConfirmDialog({
    required String title,
    required String message,
    required String cancelLabel,
    required String confirmLabel,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        actionsPadding: const EdgeInsets.only(right: 16, bottom: 8, top: 0),
        backgroundColor: Theme.of(context).colorScheme.tertiary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.primary,
            fontSize: 18,
          ),
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width,
          child: Text(message),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(cancelLabel, style: TextStyle(color: Colors.grey[600])),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              confirmLabel,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
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
    if (text.isEmpty && _sessionManager.attachedImageFiles.isEmpty) return;

    _messageController.clear();

    await _sessionManager.sendMessage(
      text: text,
      images: _sessionManager.attachedImageFiles
          .map((f) => AppImage(localFile: f))
          .toList(),
    );
  }

  void _removeAttachedImage(int index) {
    _sessionManager.removeAttachedImage(index);
  }

  void _previewAttachedImage(int index) {
    final files = _sessionManager.attachedImageFiles;
    if (index < 0 || index >= files.length) return;
    FullScreenImagePreview.show(context, imageFile: files[index]);
  }

  // ============================================================
  // ATTACHMENT HANDLING
  // ============================================================

  void _onAttachPressed() {
    AttachmentSheet.show(
      context,
      onSourceSelected: (source) => _handleImageCapture(
        source,
        onImagePicked: (file) {
          _sessionManager.addAttachedImage(file);
        },
        showLoading: false,
      ),
    );
  }

  Future<void> _handleImageCapture(
    ImageSource source, {
    void Function(File)? onImagePicked,
    bool? showLoading = true,
  }) async {
    final canProceed = await checkLimitsAndProceed(context);
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
        onImagePicked?.call(file);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
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
        label: _sessionManager.getErrorActionLabel(messageErrorType),
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
      label: _sessionManager.getErrorActionLabel(messageErrorType),
      handleAction: () =>
          _sessionManager.retryLastFailedAction(errorType: messageErrorType),
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
        onPressed: () => popDetailOrGoHome(
          context,
          result: _sessionManager.sessionsListStale,
        ),
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

        if (sessionManager.selectedSessionError != null && !_isNewSession) {
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
    final showActionCard = _shouldShowInitialActionCard;

    final isTextFieldDisabled =
        sessionManager.createSessionError != null ||
        sessionManager.isCreatingSession;

    return Column(
      children: [
        Expanded(child: _buildMessageList(sessionManager, messages)),
        ListenableBuilder(
          listenable: _messageController,
          builder: (context, _) {
            final noInput =
                _messageController.text.isEmpty &&
                sessionManager.attachedImageFiles.isEmpty;

            final isSendDisabled =
                sessionManager.isSelectedSessionAwaitingResponse ||
                sessionManager.isSelectedSessionStreaming ||
                sessionManager.createSessionError != null ||
                showActionCard ||
                noInput;

            return MessageInput(
              messageController: _messageController,
              onSendMessage: _sendMessage,
              isSendDisabled: isSendDisabled,
              isTextFieldDisabled: isTextFieldDisabled,
              autofocus: _isNewSession && !showActionCard,
              focusNode: _inputFocusNode,
              placeholder: UxMessages.styleAnalysisChatInputPlaceholder,
              onAttachPressed: _isNewSession ? null : _onAttachPressed,
              attachedImages: sessionManager.attachedImageFiles,
              onRemoveImage: _removeAttachedImage,
              onPreviewImage: _previewAttachedImage,
            );
          },
        ),
      ],
    );
  }

  Widget _buildMessageList(
    StyleAnalysisSessionManager sessionManager,
    List<StyleAnalysisSessionMessage> messages,
  ) {
    final showActionCard = _shouldShowInitialActionCard;
    final itemCount =
        messages.length +
        (sessionManager.isLoadingMoreMessages ? 1 : 0) +
        (showActionCard ? 1 : 0);

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
          // 1. Initial Action Card (at the bottom of chat, index 0 in reversed list)
          if (showActionCard && index == 0) {
            return ActionCard(
              title: 'Ready to style!',
              subtitle:
                  'Take a photo of your outfit or upload one from your gallery to get started.',
              onActionSelected: (source) => _handleImageCapture(
                source,
                onImagePicked: (file) {
                  _sessionManager.submitInitialOutfit([
                    AppImage(localFile: file),
                  ]);
                },
              ),
            );
          }

          // Adjust index if action card is shown
          final messageIndex = showActionCard ? index - 1 : index;

          // 2. Loading indicator for pagination (at the top of chat, last index)
          if (sessionManager.isLoadingMoreMessages &&
              messageIndex == messages.length) {
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

          if (messageIndex < 0) return const SizedBox.shrink();

          final message = messages[messageIndex];

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
