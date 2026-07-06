import 'package:flutter/foundation.dart';
import 'package:gostylens/core/services/api_service/index.dart';
import 'package:gostylens/models/action_state.dart';
import 'package:gostylens/models/api_responses/pagination_info.dart';
import 'package:gostylens/models/style_analysis_session.dart';

/// Merges a fresh page-1 fetch into [existing], updating overlapping sessions
/// and retaining items from pages 2+ that are not in the fresh results.
@visibleForTesting
List<StyleAnalysisSession> mergePageOne(
  List<StyleAnalysisSession> existing,
  List<StyleAnalysisSession> freshPageOne,
) {
  final freshIds = freshPageOne.map((s) => s.id).toSet();
  final tail = existing.where((s) => !freshIds.contains(s.id)).toList();
  final merged = [...freshPageOne, ...tail];
  merged.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  return merged;
}

/// Manages operations for the sessions list
/// State is stored in the parent manager's _stateSlices map
class SessionsSlice {
  final StyleAnalysisApiService _apiService;
  final ActionState<List<StyleAnalysisSession>> Function() _getState;
  final void Function(ActionState<List<StyleAnalysisSession>>) _setState;
  final void Function() _notifyListeners;

  // --- Pagination State ---
  PaginationInfo? _paginationInfo;
  bool _isLoadingMore = false;
  bool? _isFavouriteFilter;

  SessionsSlice({
    required StyleAnalysisApiService apiService,
    required ActionState<List<StyleAnalysisSession>> Function() getState,
    required void Function(ActionState<List<StyleAnalysisSession>>) setState,
    required void Function() notifyListeners,
  }) : _apiService = apiService,
       _getState = getState,
       _setState = setState,
       _notifyListeners = notifyListeners;

  // --- Getters ---
  List<StyleAnalysisSession> get sessions => _getState().data ?? [];
  bool get isLoading => _getState().isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _paginationInfo?.hasNextPage ?? false;
  int get currentPage => _paginationInfo?.page ?? 1;
  int get totalCount => _paginationInfo?.totalItems ?? 0;
  String? get error => _getState().error;

  // --- Operations ---
  Future<void> fetch({
    bool forceRefresh = false,
    bool? isFavourite,
    bool silent = false,
  }) async {
    // Only fetch fresh data if forceRefresh is explicitly requested, or if the filter changed.
    final filterChanged = isFavourite != _isFavouriteFilter;

    if (forceRefresh || filterChanged) {
      _paginationInfo = null;
      // If the filter changed, we can optimistically filter the current list
      // to avoid a jarring transition while the new data loads.
      if (filterChanged && !forceRefresh) {
        final currentData = _getState().data ?? [];
        if (isFavourite == true) {
          final optimisticData = currentData
              .where((s) => s.isFavorite)
              .toList();
          _setState(ActionState.success(optimisticData));
        }
        // If switching to 'All', we keep the current favorites list
        // as a starting point while the full list loads.
      }
    }

    _isFavouriteFilter = isFavourite;

    if (!silent || (_getState().data ?? []).isEmpty) {
      _setState(ActionState.loading(data: _getState().data));
      _notifyListeners();
    }

    final response = await _apiService.fetchSessions(
      isFavourite: isFavourite,
      forceRefresh: forceRefresh,
    );

    if (response.isSuccess && response.data != null) {
      final paginatedResponse = response.data!;
      final sessions = paginatedResponse.items;

      _paginationInfo = paginatedResponse.pagination;

      _setState(ActionState.success(sessions));
    } else if (!silent || sessions.isEmpty) {
      _setState(
        ActionState.error(response.error?.message ?? 'Failed to load sessions'),
      );
    }
    _notifyListeners();
  }

  Future<void> refreshPreservingPagination({bool silent = false}) async {
    final existing = sessions;
    final previouslyHadNext = _paginationInfo?.hasNextPage ?? false;
    final previousPage = _paginationInfo?.page ?? 1;

    if (!silent || existing.isEmpty) {
      _setState(ActionState.loading(data: existing));
      _notifyListeners();
    }

    final response = await _apiService.fetchSessions(
      isFavourite: _isFavouriteFilter,
      forceRefresh: true,
    );

    if (response.isSuccess && response.data != null) {
      final paginatedResponse = response.data!;
      final freshPageOne = paginatedResponse.items;
      final freshPagination = paginatedResponse.pagination;

      final merged = mergePageOne(existing, freshPageOne);

      _paginationInfo = PaginationInfo(
        page: previousPage > freshPagination.page
            ? previousPage
            : freshPagination.page,
        pageSize: freshPagination.pageSize,
        totalItems: freshPagination.totalItems,
        totalPages: freshPagination.totalPages,
        hasNextPage: freshPagination.hasNextPage || previouslyHadNext,
        hasPreviousPage: freshPagination.hasPreviousPage,
      );

      _setState(ActionState.success(merged));
    } else if (!silent || existing.isEmpty) {
      _setState(
        ActionState.error(response.error?.message ?? 'Failed to load sessions'),
      );
    }
    _notifyListeners();
  }

  void bumpSessionActivity(String sessionId, {String? title}) {
    final index = sessions.indexWhere((s) => s.id == sessionId);
    if (index == -1) return;

    final updated = List<StyleAnalysisSession>.from(sessions);
    updated[index] = updated[index].copyWith(
      updatedAt: DateTime.now(),
      title: title,
    );
    updated.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    _setState(ActionState.success(updated));
    _notifyListeners();
  }

  Future<void> loadMore() async {
    if (!hasMore || _isLoadingMore || isLoading) return;

    _isLoadingMore = true;
    _notifyListeners();

    final response = await _apiService.fetchSessions(
      page: currentPage + 1,
      isFavourite: _isFavouriteFilter,
    );

    if (response.isSuccess && response.data != null) {
      final paginatedResponse = response.data!;
      final newSessions = paginatedResponse.items;

      _paginationInfo = paginatedResponse.pagination;

      final updatedSessions = [...sessions, ...newSessions];
      _setState(ActionState.success(updatedSessions));
    }

    _isLoadingMore = false;
    _notifyListeners();
  }

  Future<bool> delete(
    String sessionId, {
    bool optimistic = true,
    void Function(String error)? onError,
  }) async {
    if (optimistic) {
      return _deleteOptimistic(sessionId, onError: onError);
    }
    return _deleteWithConfirmation(sessionId);
  }

  Future<bool> _deleteOptimistic(
    String sessionId, {
    void Function(String error)? onError,
  }) async {
    final previousSessions = List<StyleAnalysisSession>.from(sessions);

    final updated = sessions.where((s) => s.id != sessionId).toList();
    _setState(ActionState.success(updated));
    _notifyListeners();

    final response = await _apiService.deleteSession(sessionId);

    //  If failed, rollback
    if (!response.isSuccess) {
      _setState(ActionState.success(previousSessions));
      _notifyListeners();
      onError?.call(response.error?.message ?? 'Failed to delete session');
      return false;
    }

    return true;
  }

  Future<bool> _deleteWithConfirmation(String sessionId) async {
    final response = await _apiService.deleteSession(sessionId);

    if (response.isSuccess) {
      final updated = sessions.where((s) => s.id != sessionId).toList();
      _setState(ActionState.success(updated));
      _notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> toggleFavorite(
    String sessionId,
    bool isFavorite, {
    void Function(String error)? onError,
  }) async {
    final previousSessions = List<StyleAnalysisSession>.from(sessions);

    final updated = sessions
        .map((s) => s.id == sessionId ? s.copyWith(isFavorite: isFavorite) : s)
        .where((s) => _isFavouriteFilter != true || s.isFavorite)
        .toList();

    _setState(ActionState.success(updated));
    _notifyListeners();

    final response = await _apiService.toggleFavorite(sessionId, isFavorite);

    if (!response.isSuccess) {
      _setState(ActionState.success(previousSessions));
      _notifyListeners();
      onError?.call(
        response.error?.message ?? 'Failed to update favorite status',
      );
      return false;
    }

    return true;
  }

  Future<bool> renameSession(
    String sessionId,
    String title, {
    void Function(String error)? onError,
  }) async {
    final previousSessions = List<StyleAnalysisSession>.from(sessions);

    final updated = sessions.map((s) {
      if (s.id == sessionId) {
        return s.copyWith(title: title);
      }
      return s;
    }).toList();

    _setState(ActionState.success(updated));
    _notifyListeners();

    final response = await _apiService.updateSessionProperties(sessionId, {
      'title': title,
    });

    if (!response.isSuccess) {
      _setState(ActionState.success(previousSessions));
      _notifyListeners();
      onError?.call(response.error?.message ?? 'Failed to rename session');
      return false;
    }

    return true;
  }
}
