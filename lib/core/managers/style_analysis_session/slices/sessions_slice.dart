import 'package:stylens_app/core/services/style_analysis_api_service.dart';
import 'package:stylens_app/models/action_state.dart';
import 'package:stylens_app/models/style_analysis_session.dart';

/// Manages operations for the sessions list
/// State is stored in the parent manager's _stateSlices map
class SessionsSlice {
  final StyleAnalysisApiService _apiService;
  final ActionState<List<StyleAnalysisSession>> Function() _getState;
  final void Function(ActionState<List<StyleAnalysisSession>>) _setState;
  final void Function() _notifyListeners;

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
  String? get error => _getState().error;

  // --- Operations ---
  Future<void> fetch() async {
    _setState(ActionState.loading());
    _notifyListeners();

    final response = await _apiService.fetchSessions();

    if (response.isSuccess && response.data != null) {
      final sessions = response.data!;
      sessions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      _setState(ActionState.success(sessions));
    } else {
      _setState(ActionState.error(response.error ?? 'Failed to load sessions'));
    }
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
}
