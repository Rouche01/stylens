enum UserFetchStatus { initial, loading, ready, onboarding, error }

class UserOperationState {
  final UserFetchStatus fetchStatus;
  final bool isCreating;
  final bool isUpdating;
  final bool isDeleting;

  const UserOperationState({
    this.fetchStatus = UserFetchStatus.initial,
    this.isCreating = false,
    this.isUpdating = false,
    this.isDeleting = false,
  });

  bool get isBusy =>
      isCreating ||
      isUpdating ||
      isDeleting ||
      fetchStatus == UserFetchStatus.loading;

  UserOperationState copyWith({
    bool? isCreating,
    bool? isUpdating,
    bool? isDeleting,
    UserFetchStatus? fetchStatus,
  }) {
    return UserOperationState(
      isCreating: isCreating ?? this.isCreating,
      isUpdating: isUpdating ?? this.isUpdating,
      isDeleting: isDeleting ?? this.isDeleting,
      fetchStatus: fetchStatus ?? this.fetchStatus,
    );
  }
}
