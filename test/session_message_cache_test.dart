import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gostylens/core/managers/asset_upload_manager.dart';
import 'package:gostylens/core/managers/style_analysis_session/actions/selected_session_actions.dart';
import 'package:gostylens/core/managers/style_analysis_session/session_message_cache.dart';
import 'package:gostylens/core/managers/style_analysis_session/index.dart';
import 'package:gostylens/core/managers/style_analysis_session/slices/selected_session_slice.dart';
import 'package:gostylens/core/services/api_service/asset_api_service.dart';
import 'package:gostylens/core/services/api_service/style_analysis_api_service.dart';
import 'package:gostylens/models/action_state.dart';
import 'package:gostylens/models/api_responses/api_response.dart';
import 'package:gostylens/models/api_responses/paginated_response.dart';
import 'package:gostylens/models/api_responses/pagination_info.dart';
import 'package:gostylens/models/selected_session.dart';
import 'package:gostylens/models/style_analysis_session_message.dart';

void main() {
  group('mergeMessagesPageOne', () {
    StyleAnalysisSessionMessage message(DateTime at, {String? text}) {
      return StyleAnalysisSessionMessage(
        timestamp: at,
        role: UserRole.user,
        text: text ?? 'msg-${at.millisecondsSinceEpoch}',
      );
    }

    test('replaces head and keeps loaded older pages', () {
      final existing = [
        message(DateTime(2024, 1, 10), text: 'old-head'),
        for (var i = 9; i >= 1; i--) message(DateTime(2024, 1, i)),
      ];
      final freshPageOne = [
        message(DateTime(2024, 2, 1), text: 'new-head'),
        for (var i = 9; i >= 2; i--) message(DateTime(2024, 1, i)),
      ];

      final merged = mergeMessagesPageOne(existing, freshPageOne);

      expect(merged.length, 10);
      expect(merged.first.text, 'new-head');
      expect(merged.last.timestamp, DateTime(2024, 1, 1));
    });
  });

  group('SessionMessageCache', () {
    StyleAnalysisSessionMessage message(String text) {
      return StyleAnalysisSessionMessage(
        timestamp: DateTime.now(),
        role: UserRole.user,
        text: text,
      );
    }

    SessionMessageCacheEntry entry(String text) {
      return SessionMessageCacheEntry(
        messages: [message(text)],
        cachedAt: DateTime.now(),
      );
    }

    test('put and get round-trip', () {
      final cache = SessionMessageCache();
      cache.put('s1', entry('hello'));

      expect(cache.contains('s1'), isTrue);
      expect(cache.get('s1')?.messages.first.text, 'hello');
    });

    test('contains is false for missing or empty messages', () {
      final cache = SessionMessageCache();
      expect(cache.contains('missing'), isFalse);

      cache.put(
        'empty',
        SessionMessageCacheEntry(messages: const [], cachedAt: DateTime.now()),
      );
      expect(cache.contains('empty'), isFalse);
    });

    test('evicts oldest entry when over maxSize', () {
      final cache = SessionMessageCache(maxSize: 2);
      cache.put('s1', entry('one'));
      cache.put('s2', entry('two'));
      cache.put('s3', entry('three'));

      expect(cache.contains('s1'), isFalse);
      expect(cache.contains('s2'), isTrue);
      expect(cache.contains('s3'), isTrue);
    });

    test('get touches LRU so recently read entry is kept', () {
      final cache = SessionMessageCache(maxSize: 2);
      cache.put('s1', entry('one'));
      cache.put('s2', entry('two'));

      expect(cache.get('s1'), isNotNull);

      cache.put('s3', entry('three'));

      expect(cache.contains('s1'), isTrue);
      expect(cache.contains('s2'), isFalse);
      expect(cache.contains('s3'), isTrue);
    });

    test('clear removes all entries', () {
      final cache = SessionMessageCache();
      cache.put('s1', entry('hello'));
      cache.clear();

      expect(cache.contains('s1'), isFalse);
      expect(cache.get('s1'), isNull);
    });
  });

  group('SelectedSessionSlice message cache', () {
    StyleAnalysisSessionMessage message(
      DateTime at, {
      String? text,
      UserRole role = UserRole.user,
    }) {
      return StyleAnalysisSessionMessage(
        timestamp: at,
        role: role,
        text: text ?? 'msg-${at.millisecondsSinceEpoch}',
      );
    }

    PaginationInfo pagination({
      int page = 1,
      bool hasNextPage = false,
    }) {
      return PaginationInfo(
        page: page,
        pageSize: 10,
        totalItems: 20,
        totalPages: 2,
        hasNextPage: hasNextPage,
        hasPreviousPage: page > 1,
      );
    }

    ApiResponse<PaginatedResponse<StyleAnalysisSessionMessage>> pageResponse({
      required int page,
      required List<StyleAnalysisSessionMessage> items,
      bool hasNextPage = false,
    }) {
      return ApiResponse.success(
        PaginatedResponse(
          items: items,
          pagination: pagination(page: page, hasNextPage: hasNextPage),
        ),
      );
    }

    late ActionState<SelectedStyleAnalysisSession> state;
    late _FakeMessagesApiService api;
    late SelectedSessionSlice slice;

    setUp(() {
      final getIt = GetIt.instance;
      if (!getIt.isRegistered<AssetApiService>()) {
        getIt.registerSingleton<AssetApiService>(AssetApiService());
      }
      if (!getIt.isRegistered<AssetUploadManager>()) {
        getIt.registerSingleton<AssetUploadManager>(AssetUploadManager());
      }

      state = ActionState<SelectedStyleAnalysisSession>.initial();
      api = _FakeMessagesApiService();
      slice = SelectedSessionSlice(
        apiService: api,
        assetApiService: getIt<AssetApiService>(),
        assetUploadManager: getIt<AssetUploadManager>(),
        getState: () => state,
        setState: (newState) => state = newState,
        notifyListeners: () {},
      );
    });

    tearDown(() {
      final getIt = GetIt.instance;
      if (getIt.isRegistered<AssetApiService>()) {
        getIt.unregister<AssetApiService>();
      }
      if (getIt.isRegistered<AssetUploadManager>()) {
        getIt.unregister<AssetUploadManager>();
      }
    });

    test('select restores messages after releaseActiveSession', () {
      slice.select('s1');
      slice.addMessage(UserRole.user, text: 'hello');

      slice.releaseActiveSession();
      expect(slice.sessionId, isNull);

      slice.select('s1');

      expect(slice.messages.length, 1);
      expect(slice.messages.first.text, 'hello');
      expect(slice.hasCachedMessages('s1'), isTrue);
    });

    test('fetchMessages silent keeps isLoading false during request', () async {
      final completer =
          Completer<ApiResponse<PaginatedResponse<StyleAnalysisSessionMessage>>>();

      slice.select('s1');
      slice.addMessage(UserRole.user, text: 'cached');
      slice.releaseActiveSession();
      slice.select('s1');

      api.enqueueFuture(completer.future);

      final fetchFuture = slice.fetchMessages(silent: true);
      expect(slice.isLoading, isFalse);

      completer.complete(
        pageResponse(
          page: 1,
          items: [message(DateTime(2024, 1, 2), text: 'fresh')],
        ),
      );
      await fetchFuture;
    });

    test('refreshMessagesPreservingPagination keeps messages beyond page 1', () async {
      api.enqueue(
        pageResponse(
          page: 1,
          items: [for (var i = 10; i >= 1; i--) message(DateTime(2024, 1, i))],
          hasNextPage: true,
        ),
      );
      api.enqueue(
        pageResponse(
          page: 2,
          items: [for (var i = 20; i >= 11; i--) message(DateTime(2024, 1, i))],
        ),
      );

      slice.select('s1');
      await slice.fetchMessages();
      await slice.loadMoreMessages();
      expect(slice.messages.length, 20);

      api.enqueue(
        pageResponse(
          page: 1,
          items: [
            message(DateTime(2024, 2, 1), text: 'newest'),
            for (var i = 10; i >= 2; i--) message(DateTime(2024, 1, i)),
          ],
        ),
      );

      await slice.refreshMessagesPreservingPagination(silent: true);

      expect(slice.messages.length, 20);
      expect(slice.messages.first.text, 'newest');
    });

    test('clearMessageCache removes restored messages on next select', () {
      slice.select('s1');
      slice.addMessage(UserRole.user, text: 'hello');
      slice.releaseActiveSession();

      slice.clearMessageCache();
      slice.select('s1');

      expect(slice.messages, isEmpty);
      expect(slice.hasCachedMessages('s1'), isFalse);
    });

    test('clearMessageCache clears saved draft text', () {
      slice.select('s1');
      slice.saveDraftText('draft');
      slice.releaseActiveSession();

      slice.clearMessageCache();
      slice.select('s1');

      expect(slice.draftText, isNull);
    });
  });

  group('StyleAnalysisSessionManager clearMessageCache', () {
    late StyleAnalysisSessionManager manager;

    setUp(() {
      final getIt = GetIt.instance;
      if (getIt.isRegistered<StyleAnalysisApiService>()) {
        getIt.unregister<StyleAnalysisApiService>();
      }
      if (getIt.isRegistered<AssetApiService>()) {
        getIt.unregister<AssetApiService>();
      }
      if (getIt.isRegistered<AssetUploadManager>()) {
        getIt.unregister<AssetUploadManager>();
      }

      getIt.registerSingleton<StyleAnalysisApiService>(
        _FakeMessagesApiService(),
      );
      getIt.registerSingleton<AssetApiService>(AssetApiService());
      getIt.registerSingleton<AssetUploadManager>(AssetUploadManager());

      manager = StyleAnalysisSessionManager();
    });

    tearDown(() {
      manager.dispose();
      final getIt = GetIt.instance;
      if (getIt.isRegistered<StyleAnalysisApiService>()) {
        getIt.unregister<StyleAnalysisApiService>();
      }
      if (getIt.isRegistered<AssetApiService>()) {
        getIt.unregister<AssetApiService>();
      }
      if (getIt.isRegistered<AssetUploadManager>()) {
        getIt.unregister<AssetUploadManager>();
      }
    });

    test('hasCachedMessages reflects released session state', () {
      manager.setSelectedSessionId('s1');
      manager.addToSelectedSessionMessages(UserRole.user, text: 'cached');
      manager.disposeSelectedSession();

      expect(manager.hasCachedMessages('s1'), isTrue);

      manager.clearMessageCache();
      expect(manager.hasCachedMessages('s1'), isFalse);
    });

    test('clearMessageCache clears draft text for released session', () {
      manager.setSelectedSessionId('s1');
      manager.disposeSelectedSession(messageInputText: 'saved draft');

      manager.clearMessageCache();
      manager.setSelectedSessionId('s1');

      expect(manager.selectedSessionDraftText, isNull);
    });
  });
}

class _FakeMessagesApiService extends StyleAnalysisApiService {
  final List<Future<ApiResponse<PaginatedResponse<StyleAnalysisSessionMessage>>>>
      _queue = [];

  void enqueue(
    ApiResponse<PaginatedResponse<StyleAnalysisSessionMessage>> response,
  ) {
    _queue.add(Future.value(response));
  }

  void enqueueFuture(
    Future<ApiResponse<PaginatedResponse<StyleAnalysisSessionMessage>>> future,
  ) {
    _queue.add(future);
  }

  @override
  Future<ApiResponse<PaginatedResponse<StyleAnalysisSessionMessage>>>
      fetchSessionMessages(
    String sessionId, {
    int page = 1,
    int pageSize = 10,
  }) {
    if (_queue.isEmpty) {
      throw StateError('No fake fetchSessionMessages response queued');
    }
    return _queue.removeAt(0);
  }
}
