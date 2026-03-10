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

      if (response.isSuccess && userData != null) {
        _currentUser = userData;
        _subscriptionManager.initialize(
          userData.id,
          initialSubscription: userData.subscription,
        );
        onSuccess?.call(userData);
      } else {
        onError?.call(response.error ?? 'Failed to load user profile.');
      }
    } catch (e) {
      onError?.call('Error fetching user profile: $e');
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

  /// Clears the user state. Should be called when logging out.
  void clearUser() {
    _currentUser = null;
    _registrationDraft = null;
    notifyListeners();
  }
}
