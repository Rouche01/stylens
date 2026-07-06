import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gostylens/core/managers/style_analysis_session/slices/sessions_slice.dart';
import 'package:gostylens/core/services/api_service/style_analysis_api_service.dart';
import 'package:gostylens/models/action_state.dart';
import 'package:gostylens/models/api_responses/api_response.dart';
import 'package:gostylens/models/api_responses/paginated_response.dart';
import 'package:gostylens/models/api_responses/pagination_info.dart';
import 'package:gostylens/models/style_analysis_session.dart';

void main() {
  group('mergePageOne', () {
    StyleAnalysisSession session(String id, DateTime updatedAt) {
      return StyleAnalysisSession(
        id: id,
        userId: 'user-1',
        title: 'Session $id',
        createdAt: updatedAt,
        updatedAt: updatedAt,
      );
    }

    test('retains tail items and updates overlapping ids from page 1', () {
      final tNewest = DateTime(2024, 2, 1);

      final existing = [
        for (var i = 1; i <= 30; i++)
          session('s$i', DateTime(2024, 1, i)),
      ];

      final freshPageOne = [
        session('s1', tNewest).copyWith(title: 'Updated s1'),
        session('s2', DateTime(2024, 1, 2)),
        for (var i = 3; i <= 10; i++) session('s$i', DateTime(2024, 1, i)),
      ];

      final merged = mergePageOne(existing, freshPageOne);

      expect(merged.length, 30);
      expect(merged.first.id, 's1');
      expect(merged.first.title, 'Updated s1');
      expect(merged.first.updatedAt, tNewest);
      expect(merged.any((s) => s.id == 's30'), isTrue);
    });

    test('sorts merged list by updatedAt descending', () {
      final existing = [
        session('old', DateTime(2024, 1, 1)),
        session('tail', DateTime(2024, 1, 2)),
      ];
      final fresh = [session('old', DateTime(2024, 6, 1))];

      final merged = mergePageOne(existing, fresh);

      expect(merged.first.id, 'old');
      expect(merged.last.id, 'tail');
    });
  });

  group('SessionsSlice', () {
    StyleAnalysisSession session(String id, {DateTime? updatedAt}) {
      final at = updatedAt ?? DateTime(2024, 1, 1);
      return StyleAnalysisSession(
        id: id,
        userId: 'user-1',
        title: 'Session $id',
        createdAt: at,
        updatedAt: at,
      );
    }

    PaginationInfo pagination({
      int page = 1,
      bool hasNextPage = false,
    }) {
      return PaginationInfo(
        page: page,
        pageSize: 10,
        totalItems: 30,
        totalPages: 3,
        hasNextPage: hasNextPage,
        hasPreviousPage: page > 1,
      );
    }

    ApiResponse<PaginatedResponse<StyleAnalysisSession>> pageResponse({
      required int page,
      required List<StyleAnalysisSession> items,
      bool hasNextPage = false,
    }) {
      return ApiResponse.success(
        PaginatedResponse(
          items: items,
          pagination: pagination(page: page, hasNextPage: hasNextPage),
        ),
      );
    }

    late ActionState<List<StyleAnalysisSession>> state;
    late _FakeStyleAnalysisApiService api;
    late SessionsSlice slice;
  var notifyCount = 0;

    setUp(() {
      state = ActionState<List<StyleAnalysisSession>>.initial();
      notifyCount = 0;
      api = _FakeStyleAnalysisApiService();
      slice = SessionsSlice(
        apiService: api,
        getState: () => state,
        setState: (newState) => state = newState,
        notifyListeners: () => notifyCount++,
      );
    });

    test('silent fetch keeps isLoading false while request is in flight', () async {
      final completer =
          Completer<ApiResponse<PaginatedResponse<StyleAnalysisSession>>>();
      api.enqueueFuture(completer.future);

      state = ActionState.success([session('existing')]);

      final fetchFuture = slice.fetch(forceRefresh: true, silent: true);
      expect(slice.isLoading, isFalse);

      completer.complete(pageResponse(page: 1, items: [session('s1')]));
      await fetchFuture;
    });

    test('refreshPreservingPagination keeps pages 2+ after head refresh', () async {
      api.enqueue(pageResponse(
        page: 1,
        items: [for (var i = 1; i <= 10; i++) session('s$i')],
        hasNextPage: true,
      ));
      api.enqueue(pageResponse(
        page: 2,
        items: [for (var i = 11; i <= 20; i++) session('s$i')],
        hasNextPage: true,
      ));

      await slice.fetch();
      await slice.loadMore();
      expect(slice.sessions.length, 20);

      api.enqueue(pageResponse(
        page: 1,
        items: [
          session('s1', updatedAt: DateTime(2024, 12, 1))
              .copyWith(title: 'Fresh s1'),
          for (var i = 2; i <= 10; i++) session('s$i'),
        ],
        hasNextPage: true,
      ));

      await slice.refreshPreservingPagination(silent: true);

      expect(slice.sessions.length, 20);
      expect(slice.sessions.first.title, 'Fresh s1');
      expect(slice.hasMore, isTrue);
      expect(slice.currentPage, 2);
    });

    test('bumpSessionActivity moves session to top', () {
      state = ActionState.success([
        session('a', updatedAt: DateTime(2024, 1, 3)),
        session('b', updatedAt: DateTime(2024, 1, 2)),
        session('c', updatedAt: DateTime(2024, 1, 1)),
      ]);

      slice.bumpSessionActivity('c');

      expect(slice.sessions.first.id, 'c');
      expect(slice.sessions.last.id, 'b');
    });
  });
}

class _FakeStyleAnalysisApiService extends StyleAnalysisApiService {
  final List<Future<ApiResponse<PaginatedResponse<StyleAnalysisSession>>>>
      _queue = [];

  void enqueue(
    ApiResponse<PaginatedResponse<StyleAnalysisSession>> response,
  ) {
    _queue.add(Future.value(response));
  }

  void enqueueFuture(
    Future<ApiResponse<PaginatedResponse<StyleAnalysisSession>>> future,
  ) {
    _queue.add(future);
  }

  @override
  Future<ApiResponse<PaginatedResponse<StyleAnalysisSession>>> fetchSessions({
    int page = 1,
    int pageSize = 10,
    bool? isFavourite,
    bool forceRefresh = false,
  }) {
    if (_queue.isEmpty) {
      throw StateError('No fake fetchSessions response queued');
    }
    return _queue.removeAt(0);
  }
}
