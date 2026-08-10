import 'package:flutter/foundation.dart';
import 'package:gostylens/constants/ux_messages.dart';
import 'package:gostylens/core/config/dependency_injection.dart';
import 'package:gostylens/core/managers/slice_state_manager.dart';
import 'package:gostylens/core/managers/stylist_openers_manager.dart';
import 'package:gostylens/core/services/analytics_service.dart';
import 'package:gostylens/core/services/api_service/index.dart';
import 'package:gostylens/models/api_responses/pagination_info.dart';
import 'package:gostylens/models/api_responses/stylist_openers.dart';
import 'package:gostylens/models/style_analysis_session_message.dart';
import 'package:gostylens/models/style_analysis_session_message_error.dart';
import 'package:gostylens/models/app_image.dart';
import 'package:gostylens/models/remote_image.dart';
import 'package:gostylens/models/selected_session.dart';
import 'package:gostylens/core/managers/style_analysis_session/slices/session_streaming_slice.dart';
import 'package:gostylens/core/managers/asset_upload_manager.dart';

/// Merges a fresh page-1 message fetch into [existing], replacing the head
/// segment and retaining older pages already loaded beyond page 1.
@visibleForTesting
List<StyleAnalysisSessionMessage> mergeMessagesPageOne(
  List<StyleAnalysisSessionMessage> existing,
  List<StyleAnalysisSessionMessage> freshPageOne,
) {
  if (freshPageOne.isEmpty) return existing;
  if (existing.isEmpty) return freshPageOne;
  if (existing.length <= freshPageOne.length) return freshPageOne;

  final tail = existing.sublist(freshPageOne.length);
  return [...freshPageOne, ...tail];
}

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
    List<AppImage>? images,
    bool isLoading = false,
    StyleAnalysisSessionMessageError? error,
  });

  void addLoadingMessage();
  void removeLoadingMessage();
  void replaceLoadingWithError(StyleAnalysisSessionMessageError error);
  void saveDraftText(String text);
  void clearAttachedImages();

  bool hasCachedMessages(String sessionId);
  void persistMessageCache();

  /// Clears the selected session and returns a generation token for local
  /// bootstrap work (empty / outfit start). Stale async steps must no-op when
  /// [isLocalBootstrapCurrent] is false.
  int beginLocalSessionBootstrap();

  bool isLocalBootstrapCurrent(int generation);

  /// Generation of the active local bootstrap (or last invalidate).
  int get localBootstrapGeneration;

  // --- Actions Mixin Logic ---
  static const _initialPrompt = UxMessages.initialOutfitPromptTextAugmentation;

  Future<void> _warmStylistOpenersCache() async {
    if (!locator.isRegistered<StylistOpenersManager>()) return;
    try {
      await locator<StylistOpenersManager>().warmCache();
    } catch (e) {
      debugPrint('Failed to warm stylist openers cache: $e');
    }
  }

  String _pickOpener(StylistOpenerTag tag) {
    if (!locator.isRegistered<StylistOpenersManager>()) {
      return tag == StylistOpenerTag.withImage
          ? UxMessages.initialStylistReplyWithImage
          : UxMessages.initialStylistReplyWithoutImage1;
    }
    return locator<StylistOpenersManager>().pickOne(tag);
  }

  // Pagination State
  PaginationInfo? paginationInfo;
  bool isLoadingMoreMessages = false;

  bool get hasMoreMessages => paginationInfo?.hasNextPage ?? false;
  int get currentPage => paginationInfo?.page ?? 1;

  // --- Fetch Messages ---
  Future<bool> fetchMessages({
    bool silent = false,
    bool forceRefresh = false,
  }) async {
    final id = sessionId;
    if (id == null) {
      sliceStateManager.setError('No session selected');
      return false;
    }

    if (hasCachedMessages(id) && messages.isNotEmpty && !forceRefresh) {
      return refreshMessagesPreservingPagination(silent: silent);
    }

    final shouldSetLoading = !silent || messages.isEmpty;

    final response = await sliceStateManager.execute(
      action: () => apiService.fetchSessionMessages(id),
      setLoadingState: shouldSetLoading,
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

    if (response != null) {
      persistMessageCache();
    }

    return response != null;
  }

  Future<bool> refreshMessagesPreservingPagination({
    bool silent = false,
  }) async {
    final id = sessionId;
    if (id == null) return false;

    final existing = messages;
    final previouslyHadNext = paginationInfo?.hasNextPage ?? false;
    final previousPage = paginationInfo?.page ?? 1;
    final shouldSetLoading = !silent || existing.isEmpty;

    try {
      if (shouldSetLoading) {
        sliceStateManager.setLoading(
          data: SelectedStyleAnalysisSession(
            sessionId: id,
            messages: existing,
          ),
        );
      }

      final response = await apiService.fetchSessionMessages(id);

      if (response.isSuccess && response.data != null) {
        final freshPageOne = response.data!.items;
        final freshPagination = response.data!.pagination;
        final merged = mergeMessagesPageOne(existing, freshPageOne);

        paginationInfo = PaginationInfo(
          page: previousPage > freshPagination.page
              ? previousPage
              : freshPagination.page,
          pageSize: freshPagination.pageSize,
          totalItems: freshPagination.totalItems,
          totalPages: freshPagination.totalPages,
          hasNextPage: freshPagination.hasNextPage || previouslyHadNext,
          hasPreviousPage: freshPagination.hasPreviousPage,
        );

        sliceStateManager.setSuccess(
          SelectedStyleAnalysisSession(sessionId: id, messages: merged),
        );
        persistMessageCache();
        return true;
      }

      if (!silent || existing.isEmpty) {
        sliceStateManager.setError(
          response.error?.message ?? 'Failed to load messages',
          retainData: existing.isNotEmpty,
        );
      }
      return false;
    } catch (e, stackTrace) {
      locator<AnalyticsService>().captureException(
        e,
        stackTrace: stackTrace,
        properties: {
          'context': 'session_message_fetch',
          'session_id': id,
        },
      );
      if (!silent || existing.isEmpty) {
        sliceStateManager.setError(
          e.toString(),
          retainData: existing.isNotEmpty,
        );
      }
      return false;
    }
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

    if (response != null) {
      persistMessageCache();
    }

    return response != null;
  }

  // --- Session Lifecycle ---
  Future<String?> create(void Function(String message)? onError) async {
    final sortedMessages = [...messages]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final messageEntries = sortedMessages
        .where((msg) => msg.text != null || (msg.images?.isNotEmpty ?? false))
        .map(
          (msg) => {
            'role': msg.role.name,
            'prompt': msg.text,
            'remoteImages': msg.images
                ?.map((i) => i.remoteImage?.toJson())
                .whereType<Map<String, dynamic>>()
                .toList(),
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

    if (response != null) {
      persistMessageCache();
    }

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
    required List<AppImage> images,
    required Future<void> Function(
      String sessionId, {
      required ContextMode contextMode,
    })
    startStreaming,
    void Function(String sessionId)? onSessionsListActivity,
  }) async {
    final id = sessionId;
    final isNew = id == null;

    // 1. Add to local UI immediately
    addMessage(UserRole.user, text: text, images: images);

    // 2. Clear draft state
    clearAttachedImages();
    saveDraftText('');
    addLoadingMessage();
    sliceStateManager.notify();

    try {
      // 3. Ensure all assets are prepared and uploads started
      final updatedImages = await assetUploadManager.ensureAssetsPrepared(
        images,
      );
      final remoteImages = updatedImages
          .map((i) => i.remoteImage)
          .whereType<RemoteImage>()
          .toList();

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
        onSessionsListActivity?.call(finalSessionId);

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
            'has_images': images.isNotEmpty,
          },
        );
      }
    } catch (e, stackTrace) {
      locator<AnalyticsService>().captureException(
        e,
        stackTrace: stackTrace,
        properties: {
          'context': 'session_message_send',
          'session_id': sessionId ?? '',
        },
      );
      replaceLoadingWithError(
        StyleAnalysisSessionMessageError.fromRawError('Error: $e'),
      );
    }
  }

  Future<void> playEmptySessionIntro(int generation) async {
    await _warmStylistOpenersCache();
    final opener = _pickOpener(StylistOpenerTag.withoutImage);

    // [prepareEmptySession] already showed a loading bubble.
    await Future.delayed(const Duration(milliseconds: 1000));
    if (!isLocalBootstrapCurrent(generation)) return;
    removeLoadingMessage();
    addMessage(UserRole.assistant, text: opener);
  }

  Future<void> playOutfitSessionIntro(int generation) async {
    List<AppImage> outfitImages = const [];
    for (final message in messages) {
      if (message.isUserMessage &&
          message.images != null &&
          message.images!.isNotEmpty) {
        outfitImages = message.images!;
        break;
      }
    }

    try {
      final updatedImages = await assetUploadManager.ensureAssetsPrepared(
        outfitImages,
      );
      if (!isLocalBootstrapCurrent(generation)) return;

      final allRemoteImages = updatedImages
          .map((i) => i.remoteImage)
          .whereType<RemoteImage>()
          .toList();
      updateLastUserMessage(remoteImages: allRemoteImages);

      await _addInitialStylistResponse(generation);
    } catch (e, stackTrace) {
      debugPrint('Error in playOutfitSessionIntro: $e');
      locator<AnalyticsService>().captureException(
        e,
        stackTrace: stackTrace,
        properties: {'context': 'session_outfit_intro'},
      );
    }
  }

  Future<void> _addInitialStylistResponse(int generation) async {
    if (!isLocalBootstrapCurrent(generation)) return;
    await _warmStylistOpenersCache();
    if (!isLocalBootstrapCurrent(generation)) return;
    final reply = _pickOpener(StylistOpenerTag.withImage);
    addLoadingMessage();
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!isLocalBootstrapCurrent(generation)) return;
    removeLoadingMessage();
    addMessage(UserRole.assistant, text: reply);
  }

  Future<void> submitInitialOutfit(
    List<AppImage> images, {
    int? bootstrapGeneration,
  }) async {
    // In-chat action card: append outfit without resetting; cancel if leave /
    // another local start invalidates [generation].
    final generation = bootstrapGeneration ?? localBootstrapGeneration;

    addMessage(UserRole.user, images: images, text: _initialPrompt);
    addLoadingMessage();
    sliceStateManager.notify();

    try {
      final updatedImages = await assetUploadManager.ensureAssetsPrepared(
        images,
      );
      if (!isLocalBootstrapCurrent(generation)) return;

      final allRemoteImages = updatedImages
          .map((i) => i.remoteImage)
          .whereType<RemoteImage>()
          .toList();
      updateLastUserMessage(remoteImages: allRemoteImages);

      await _addInitialStylistResponse(generation);
    } catch (e, stackTrace) {
      debugPrint('Error in submitInitialOutfit: $e');
      locator<AnalyticsService>().captureException(
        e,
        stackTrace: stackTrace,
        properties: {'context': 'session_submit_outfit'},
      );
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
      // Merge remote images into existing AppImage objects if they have matching local files
      // or just create new AppImage objects if no local files were present.
      final updatedImages = lastMsg.images?.map((img) {
        // If we have remote images, find the one that corresponds to this local file
        // For simplicity during transition, if we have a list of remote images of same length, we zip them.
        final index = lastMsg.images!.indexOf(img);
        if (remoteImages != null && index < remoteImages.length) {
          return AppImage(
            localFile: img.localFile,
            remoteImage: remoteImages[index],
          );
        }
        return img;
      }).toList();

      updatedMessages[lastIndex] = StyleAnalysisSessionMessage(
        text: lastMsg.text,
        role: lastMsg.role,
        timestamp: lastMsg.timestamp,
        images:
            updatedImages ??
            remoteImages?.map((ri) => AppImage(remoteImage: ri)).toList(),
        isLoading: lastMsg.isLoading,
        error: lastMsg.error,
      );

      sliceStateManager.setData(
        currentState.copyWith(messages: updatedMessages),
      );
      persistMessageCache();
    }
  }
}
