import 'package:gostylens/models/action_state.dart';
import 'package:gostylens/utils/string_extensions.dart';

enum ActionType { initial, loading, success, error }

/// A generic utility class for managing ActionState in slices
///
/// Usage:
/// ```dart
/// class MySlice {
///   late final SliceStateManager<MyData> _stateManager;
///
///   MySlice({
///     required ActionState<MyData> Function() getState,
///     required void Function(ActionState<MyData>) setState,
///     required void Function() notifyListeners,
///   }) {
///     _stateManager = SliceStateManager(
///       getState: getState,
///       setState: setState,
///       notifyListeners: notifyListeners,
///     );
///   }
/// }
/// ```

class SliceStateManager<T> {
  final ActionState<T> Function() _getState;
  final void Function(ActionState<T>) _setState;
  final void Function() _notifyListeners;

  SliceStateManager({
    required ActionState<T> Function() getState,
    required void Function(ActionState<T>) setState,
    required void Function() notifyListeners,
  }) : _getState = getState,
       _setState = setState,
       _notifyListeners = notifyListeners;

  // --- Getters ---
  ActionState<T> get state => _getState();
  T? get data => state.data;
  bool get isLoading => state.isLoading;
  String? get error => state.error;

  // --- State Updates ---

  /// Sets state to initial
  void setInitial({bool notify = true}) {
    _setState(ActionState<T>.initial());
    if (notify) _notifyListeners();
  }

  /// Sets state to loading
  void setLoading({T? data, bool notify = true}) {
    _setState(ActionState<T>.loading(data: data));
    if (notify) _notifyListeners();
  }

  /// Sets state to success with data
  void setSuccess(T data, {bool notify = true}) {
    _setState(ActionState<T>.success(data));
    if (notify) _notifyListeners();
  }

  /// Sets state to data with data (no loading state)
  void setData(T data, {bool notify = true}) {
    _setState(ActionState<T>.data(data));
    if (notify) _notifyListeners();
  }

  /// Sets state to error with message
  void setError(
    String? message, {
    bool retainData = false,
    bool notify = true,
  }) {
    _setState(ActionState<T>.error(message, data: retainData ? data : null));
    if (notify) _notifyListeners();
  }

  /// Generic state update with action type
  void update(
    ActionType actionType, {
    T? data,
    String? error,
    bool notify = true,
  }) {
    switch (actionType) {
      case ActionType.initial:
        _setState(ActionState<T>.initial());
      case ActionType.loading:
        _setState(ActionState<T>.loading(data: data));
      case ActionType.success:
        if (data != null) {
          _setState(ActionState<T>.success(data));
        }
      case ActionType.error:
        _setState(ActionState<T>.error(error, data: data));
    }
    if (notify) _notifyListeners();
  }

  /// Notifies listeners without changing state
  void notify() => _notifyListeners();

  /// Executes an async operation with automatic loading/success/error handling
  ///
  /// Usage:
  /// ```dart
  /// final result = await _stateManager.execute(
  ///   action: () => _apiService.fetchData(),
  ///   onSuccess: (response) => MyData.fromJson(response),
  ///   onError: (e) => 'Failed to fetch: $e',
  /// );
  /// ```
  Future<R?> execute<R>({
    required Future<R> Function() action,
    T Function(R result, T? currentData)? onSuccess,
    String Function(dynamic error)? onError,
    bool setLoadingState = true,
    bool retainDataOnError = false,
    bool retainDataOnLoading = false,
    T Function(String error)? setDataOnError,
  }) async {
    try {
      if (setLoadingState) {
        setLoading(data: retainDataOnLoading ? data : null);
      }

      final result = await action();

      if (onSuccess != null) {
        setSuccess(onSuccess(result, data));
      }
      return result;
    } catch (e) {
      String errorMessage = e.toString().cleanException();
      onError?.call(errorMessage);

      if (setDataOnError != null) {
        setData(setDataOnError(errorMessage));
      } else {
        setError(errorMessage, retainData: retainDataOnError);
      }
      return null;
    }
  }
}
