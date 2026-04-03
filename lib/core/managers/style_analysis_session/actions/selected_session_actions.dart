import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:gostylens/constants/ux_messages.dart';
import 'package:gostylens/core/config/dependency_injection.dart';
import 'package:gostylens/core/managers/slice_state_manager.dart';
import 'package:gostylens/core/services/analytics_service.dart';
import 'package:gostylens/core/services/api_service/index.dart';
import 'package:gostylens/models/api_responses/pagination_info.dart';
import 'package:gostylens/models/style_analysis_session_message.dart';
import 'package:gostylens/models/style_analysis_session_message_error.dart';
import 'package:gostylens/models/remote_image.dart';
import 'package:gostylens/models/selected_session.dart';
import 'package:gostylens/core/managers/style_analysis_session/slices/session_streaming_slice.dart';
import 'package:gostylens/core/managers/asset_upload_manager.dart';

mixin SelectedSessionActions {
  // --- Abstract Getters & Methods (Required for Actions) ---
  StyleAnalysisApiService get apiService;
  AssetApiService get assetApiService;
  AssetUploadManager get assetUploadManager;
  SliceStateManager<SelectedStyleAnalysisSession> get sliceStateManager;

  String? get sessionId => sliceStateManager.data?.sessionId;
  List<StyleAnalysisSessionMessage> get messages =>
      sliceStateManager.data?.messages ?? [];

  void addMessage(
    UserRole userRole, {
    String? text,
    List<File>? imageFiles,
    List<RemoteImage>? remoteImages,
    bool isLoading = false,
    StyleAnalysisSessionMessageError? error,
  });

  void addLoadingMessage();
  void removeLoadingMessage();
  void replaceLoadingWithError(StyleAnalysisSessionMessageError error);
  void saveDraftText(String text);
  void clearAttachedImages();

  // --- Actions Mixin Logic ---
  static const _initialPrompt = UxMessages.initialOutfitPromptTextAugmentation;
  static const _initialBotReplyWithImage =
      UxMessages.initialStylistReplyWithImage;
  static const _initialBotReplyWithoutImage1 =
      UxMessages.initialStylistReplyWithoutImage1;
  static const _initialBotReplyWithoutImage2 =
      UxMessages.initialStylistReplyWithoutImage2;

  // Pagination State
  PaginationInfo? paginationInfo;
  bool isLoadingMoreMessages = false;

  bool get hasMoreMessages => paginationInfo?.hasNextPage ?? false;
  int get currentPage => paginationInfo?.page ?? 1;

  // --- Fetch Messages ---
  Future<bool> fetchMessages() async {
    final id = sessionId;
    if (id == null) {
      sliceStateManager.setError('No session selected');
      return false;
    }

    final response = await sliceStateManager.execute(
      action: () => apiService.fetchSessionMessages(id),
      retainDataOnLoading: true,
      retainDataOnError: true,
      onSuccess: (response, currentData) {
        if (response.isSuccess && response.data != null) {
          paginationInfo = response.data!.pagination;
          return SelectedStyleAnalysisSession(
            sessionId: id,
            messages: response.data!.items,
          );
        }
        throw Exception(response.error?.message ?? 'Failed to load messages');
      },
      setDataOnError: (errorMessage) {
        return SelectedStyleAnalysisSession(
          sessionId: id,
          messages: [
            StyleAnalysisSessionMessage(
              timestamp: DateTime.now(),
              role: UserRole.system,
              error: StyleAnalysisSessionMessageError(
                message: errorMessage,
                type: MessageErrorType.failedFetch,
              ),
            ),
          ],
        );
      },
    );

    return response != null;
  }

  // --- Load More Messages ---
  Future<bool> loadMoreMessages() async {
    final id = sessionId;
    if (id == null) return false;
    if (isLoadingMoreMessages) return false;
    if (!hasMoreMessages) return false;

    isLoadingMoreMessages = true;
    sliceStateManager.notify();

    final response = await sliceStateManager.execute(
      action: () => apiService.fetchSessionMessages(id, page: currentPage + 1),
      setLoadingState: false, // Don't override main loading state
      onSuccess: (response, currentData) {
        if (response.isSuccess && response.data != null) {
          paginationInfo = response.data!.pagination;
          final olderMessages = response.data!.items;

          return SelectedStyleAnalysisSession(
            sessionId: currentData?.sessionId,
            messages: [...(currentData?.messages ?? []), ...olderMessages],
          );
        }
        throw Exception(response.error ?? 'Failed to load more messages');
      },
      onError: (e) => 'Failed to load more messages: $e',
    );

    isLoadingMoreMessages = false;
    sliceStateManager.notify();

    return response != null;
  }

  // --- Session Lifecycle ---
  Future<String?> create(void Function(String message)? onError) async {
    final sortedMessages = [...messages]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final messageEntries = sortedMessages
        .where(
          (msg) => msg.text != null || (msg.remoteImages?.isNotEmpty ?? false),
        )
        .map(
          (msg) => {
            'role': msg.role.name,
            'prompt': msg.text,
            'remoteImages': msg.remoteImages?.map((i) => i.toJson()).toList(),
          },
        )
        .toList();

    final response = await sliceStateManager.execute(
      action: () => apiService.createSession(messages: messageEntries),
      retainDataOnError: true, // Keep the UI messages array alive!
      setLoadingState: false, // Don't wipe the chat view entirely
      onSuccess: (response, currentData) {
        if (response.isSuccess && response.data != null) {
          return SelectedStyleAnalysisSession(
            sessionId: response.data!,
            messages: currentData?.messages ?? [],
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
    List<RemoteImage>? remoteImages,
  }) async {
    final id = sessionId;
    if (id == null) return false;

    final response = await sliceStateManager.execute(
      action: () => apiService.addMessageToSession(
        sessionId: id,
        message: {
          'role': userRole.name,
          'prompt': text,
          'remoteImages': remoteImages?.map((i) => i.toJson()).toList(),
        },
      ),
      setLoadingState: false, // Don't change main state
      retainDataOnError: true, // Keep the UI messages untouched!
      onSuccess: (response, currentData) {
        if (response.isSuccess) {
          // Return current session state unchanged
          return currentData!;
        }
        throw Exception(response.error ?? 'Failed to add message');
      },
      onError: (e) => 'Failed to add message: $e',
    );

    return response != null;
  }

  // --- Sending Flow ---
  Future<void> sendMessage({
    required String text,
    required List<File> imageFiles,
    required Future<void> Function(
      String sessionId, {
      required ContextMode contextMode,
    })
    startStreaming,
  }) async {
    final id = sessionId;
    final isNew = id == null;

    // 1. Add to local UI immediately
    addMessage(UserRole.user, text: text, imageFiles: imageFiles);

    // 2. Clear draft state
    clearAttachedImages();
    saveDraftText('');
    addLoadingMessage();
    sliceStateManager.notify();

    try {
      // 3. Reserve Keys (Parallel Fast Requests) and Queue Background Uploads
      final remoteImages = await Future.wait<RemoteImage>(
        imageFiles.map((file) => assetUploadManager.prepareAsset(file)),
      );

      // 4. Start the binary uploads in the background (Non-awaited)
      assetUploadManager.uploadAssets(
        remoteImages.map((ri) => ri.key).toList(),
      );

      // Update local message with remote images
      updateLastUserMessage(remoteImages: remoteImages);

      // 4. Notify Backend
      String? finalSessionId = id;
      if (isNew) {
        finalSessionId = await create((message) => throw Exception(message));
      } else {
        final success = await addMessageRemote(
          UserRole.user,
          text: text,
          remoteImages: remoteImages,
        );
        if (!success) throw Exception('Failed to send message to server');
      }

      if (finalSessionId != null) {
        // 5. Trigger Assistant
        await startStreaming(
          finalSessionId,
          contextMode: isNew ? ContextMode.all : ContextMode.recent,
        );

        locator<AnalyticsService>().capture(
          'message_sent',
          properties: {
            'session_id': finalSessionId,
            'user_role': UserRole.user.name,
            'has_text': text.isNotEmpty,
            'has_images': imageFiles.isNotEmpty,
          },
        );
      }
    } catch (e) {
      replaceLoadingWithError(
        StyleAnalysisSessionMessageError(
          message: 'Error: $e. Your message could not be sent.',
        ),
      );
    }
  }

  Future<void> processInitialOutfit(
    List<File> files,
    List<RemoteImage> remoteImages,
  ) async {
    addMessage(
      UserRole.user,
      imageFiles: files,
      remoteImages: remoteImages,
      text: _initialPrompt,
    );

    addLoadingMessage();
    await Future.delayed(const Duration(milliseconds: 1500));
    removeLoadingMessage();

    addMessage(UserRole.assistant, text: _initialBotReplyWithImage);
  }

  Future<void> processInitialOutfitFlow(List<File> files) async {
    addMessage(UserRole.user, imageFiles: files, text: _initialPrompt);
    addLoadingMessage();
    sliceStateManager.notify();

    try {
      final remoteImages = await Future.wait<RemoteImage>(
        files.map((file) => assetUploadManager.prepareAsset(file)),
      );

      // Start background uploads
      assetUploadManager.uploadAssets(
        remoteImages.map((ri) => ri.key).toList(),
      );

      // Complete initial outfit process
      updateLastUserMessage(remoteImages: remoteImages);
      await processInitialOutfit(files, remoteImages);
    } catch (e) {
      debugPrint('Error in processInitialOutfitFlow: $e');
    }
  }

  Future<void> initializeNew(
    List<File>? imageFiles,
    List<RemoteImage>? remoteImages,
  ) async {
    if ((imageFiles?.isNotEmpty ?? false) ||
        (remoteImages?.isNotEmpty ?? false)) {
      await processInitialOutfit(imageFiles ?? [], remoteImages ?? []);
    } else {
      addLoadingMessage();
      await Future.delayed(const Duration(milliseconds: 1000));
      removeLoadingMessage();

      addMessage(UserRole.assistant, text: _initialBotReplyWithoutImage1);

      addLoadingMessage();
      await Future.delayed(const Duration(milliseconds: 2000));
      removeLoadingMessage();

      addMessage(UserRole.assistant, text: _initialBotReplyWithoutImage2);
    }
  }

  void updateLastUserMessage({List<RemoteImage>? remoteImages}) {
    final currentState = sliceStateManager.data;
    if (currentState == null || currentState.messages.isEmpty) return;

    final updatedMessages = List<StyleAnalysisSessionMessage>.from(
      currentState.messages,
    );
    final lastIndex = updatedMessages.lastIndexWhere((m) => m.isUserMessage);

    if (lastIndex != -1) {
      final lastMsg = updatedMessages[lastIndex];
      updatedMessages[lastIndex] = StyleAnalysisSessionMessage(
        text: lastMsg.text,
        role: lastMsg.role,
        timestamp: lastMsg.timestamp,
        imageFiles: lastMsg.imageFiles,
        remoteImages: remoteImages,
        isLoading: lastMsg.isLoading,
        error: lastMsg.error,
      );

      sliceStateManager.setData(
        currentState.copyWith(messages: updatedMessages),
      );
    }
  }
}
