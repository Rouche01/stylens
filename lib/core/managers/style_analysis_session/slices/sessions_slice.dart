import 'package:gostylens/core/services/style_analysis_api_service.dart';
import 'package:gostylens/models/action_state.dart';
import 'package:gostylens/models/api_responses/pagination_info.dart';
import 'package:gostylens/models/style_analysis_session.dart';

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
  String? get error => _getState().error;

  // --- Operations ---
  Future<void> fetch({bool refresh = false, bool? isFavourite}) async {
    // Only fetch fresh data if refresh is explicitly requested, or if the filter changed.
    final filterChanged = isFavourite != _isFavouriteFilter;

    if (refresh || filterChanged) {
      _paginationInfo = null;
      if (!refresh) {
        _setState(ActionState.success([]));
      }
    }

    _isFavouriteFilter = isFavourite;

    _setState(ActionState.loading());
    _notifyListeners();

    final response = await _apiService.fetchSessions(isFavourite: isFavourite);

    if (response.isSuccess && response.data != null) {
      final paginatedResponse = response.data!;
      final sessions = paginatedResponse.items;

      _paginationInfo = paginatedResponse.pagination;

      _setState(ActionState.success(sessions));
    } else {
      _setState(ActionState.error(response.error ?? 'Failed to load sessions'));
    }
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
      onError?.call(response.error ?? 'Failed to delete session');
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

    final updated = sessions.map((s) {
      if (s.id == sessionId) {
        return s.copyWith(isFavorite: isFavorite);
      }
      return s;
    }).toList();

    _setState(ActionState.success(updated));
    _notifyListeners();

    final response = await _apiService.toggleFavorite(sessionId, isFavorite);

    if (!response.isSuccess) {
      _setState(ActionState.success(previousSessions));
      _notifyListeners();
      onError?.call(response.error ?? 'Failed to update favorite status');
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
      onError?.call(response.error ?? 'Failed to rename session');
      return false;
    }

    return true;
  }
}
