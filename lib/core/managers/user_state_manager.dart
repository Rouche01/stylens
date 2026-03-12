import 'package:flutter/material.dart';
import 'package:gostylens/core/services/api_service/index.dart';
import 'package:gostylens/models/api_responses/user.dart';
import 'package:gostylens/models/api_responses/gender.dart';
import 'package:gostylens/models/api_responses/subscription.dart';
import 'package:gostylens/core/managers/subscription_manager.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

class UserStateManager extends ChangeNotifier {
  final UserApiService _userApiService;
  final SubscriptionManager _subscriptionManager;

  UserStateManager(this._subscriptionManager, {UserApiService? userApiService})
    : _userApiService = userApiService ?? UserApiService();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  User? _currentUser;
  User? get currentUser => _currentUser;

  bool _hasCheckedProfile = false;
  bool get hasCheckedProfile => _hasCheckedProfile;

  bool _needsOnboarding = false;
  bool get needsOnboarding => _needsOnboarding;

  String? _lastError;
  String? get lastError => _lastError;

  // Registration Draft State
  User? _registrationDraft;
  User? get registrationDraft => _registrationDraft;

  void updateRegistrationDraft({String? name, Gender? gender, String? email}) {
    if (_registrationDraft == null) {
      _registrationDraft = User(
        id: '',
        authId: '',
        name: name ?? '',
        gender: gender,
        email: email,
        createdAt: 0,
        updatedAt: 0,
        isActive: true,
        subscription: const Subscription(
          id: 'draft',
          userId: '',
          tier: 'free',
          status: 'active',
          hasReachedLimit: false,
        ),
      );
    } else {
      _registrationDraft = _registrationDraft!.copyWith(
        name: name,
        gender: gender,
        email: email,
      );
    }
    notifyListeners();
  }

  /// Fetches the profile of the currently authenticated Supabase user from the backend DB.
  Future<void> fetchCurrentUser({
    void Function(User user)? onSuccess,
    void Function(String error)? onError,
  }) async {
    final supabaseUser = Supabase.instance.client.auth.currentUser;
    if (supabaseUser == null) {
      onError?.call('No authenticated user found.');
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final response = await _userApiService.getUserByAuthId(supabaseUser.id);
      final userData = response.data;

      // Regardless of success/failure (except internal error), we've now made the first check
      _hasCheckedProfile = true;

      if (response.isSuccess && userData != null) {
        _currentUser = userData;
        _needsOnboarding = false;
        _lastError = null;
        notifyListeners();
        _subscriptionManager.initialize(
          userData.id,
          initialSubscription: userData.subscription,
        );
        onSuccess?.call(userData);
      } else if (response.statusCode == 404) {
        _needsOnboarding = true;
        _lastError = null;
        notifyListeners();
        onError?.call('Profile not found.');
      } else {
        _lastError = response.error ?? 'Failed to load user profile.';
        notifyListeners();
        onError?.call(_lastError!);
      }
    } catch (e) {
      _hasCheckedProfile = true;
      _lastError = 'Error fetching user profile: $e';
      notifyListeners();
      onError?.call(_lastError!);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Creates a new user profile in the backend DB for the authenticated Supabase user.
  Future<void> createProfile({
    void Function(User user)? onSuccess,
    void Function(String error)? onError,
  }) async {
    final supabaseUser = Supabase.instance.client.auth.currentUser;
    if (supabaseUser == null) {
      onError?.call('No authenticated user found to create profile for.');
      return;
    }

    if (_registrationDraft == null || _registrationDraft!.name.isEmpty) {
      onError?.call('Registration name is missing.');
      return;
    }

    // Default to 'Prefer not to say' if gender wasn't explicitly set in the draft
    final genderToSave = _registrationDraft!.gender ?? Gender.unspecified;

    _isLoading = true;
    notifyListeners();

    try {
      final emailToSave =
          _registrationDraft!.email?.trim() ?? supabaseUser.email?.trim();

      final response = await _userApiService.createUser(
        authId: supabaseUser.id,
        name: _registrationDraft!.name.trim(),
        gender: genderToSave.value,
        email: emailToSave,
      );
      final userData = response.data;

      if (response.isSuccess && userData != null) {
        _registrationDraft =
            null; // Clear the draft state after successful creation
        _currentUser = userData; // Save the newly created profile into memory
        _needsOnboarding =
            false; // Successfully created, no longer needs onboarding
        _lastError = null;
        notifyListeners();
        _subscriptionManager.initialize(
          userData.id,
          initialSubscription: userData.subscription,
        );

        // Refresh the session to ensure the user claim is updated
        await Supabase.instance.client.auth.refreshSession();
        onSuccess?.call(userData);
      } else {
        onError?.call(response.error ?? 'Failed to create user profile.');
      }
    } catch (e) {
      onError?.call('Error creating user profile: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Updates the current user's profile (name and/or nickname).
  Future<void> updateProfile({
    String? name,
    String? nickname,
    String? gender,
    void Function(User user)? onSuccess,
    void Function(String error)? onError,
  }) async {
    if (_currentUser == null) {
      onError?.call('No user logged in.');
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final response = await _userApiService.updateUser(
        userId: _currentUser!.id,
        name: name,
        nickname: nickname,
        gender: gender,
      );
      final userData = response.data;

      if (response.isSuccess && userData != null) {
        _currentUser = userData;
        onSuccess?.call(userData);
      } else {
        onError?.call(response.error ?? 'Failed to update profile.');
      }
    } catch (e) {
      onError?.call('Error updating profile: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Deletes the current user's account from the backend and signs them out of Supabase.
  Future<void> deleteAccount({
    void Function()? onSuccess,
    void Function(String error)? onError,
  }) async {
    if (_currentUser == null) {
      onError?.call('No user logged in.');
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final response = await _userApiService.deleteUser(_currentUser!.id);

      if (response.isSuccess) {
        // Sign out of Supabase - this will trigger AuthGate to redirect the user
        await Supabase.instance.client.auth.signOut();
        await resetState();
        onSuccess?.call();
      } else {
        onError?.call(response.error ?? 'Failed to delete account.');
      }
    } catch (e) {
      onError?.call('Error deleting account: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clears the user and subscription state. Should be called when logging out.
  Future<void> resetState() async {
    _currentUser = null;
    _registrationDraft = null;
    _hasCheckedProfile = false;
    _needsOnboarding = false;
    _lastError = null;
    await _subscriptionManager.reset();
    notifyListeners();
  }
}
