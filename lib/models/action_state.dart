class ActionState<T> {
  final bool isLoading;
  final T? data;
  final String? error;

  const ActionState({this.isLoading = false, this.data, this.error});

  ActionState.initial() : isLoading = false, data = null, error = null;

  ActionState.loading() : isLoading = true, data = null, error = null;

  ActionState.success(this.data) : isLoading = false, error = null;

  ActionState.error(this.error) : isLoading = false, data = null;

  ActionState<T> copyWith({bool? isLoading, T? data, String? error}) {
    return ActionState<T>(
      isLoading: isLoading ?? this.isLoading,
      data: data ?? this.data,
      error: error ?? this.error,
    );
  }
}
