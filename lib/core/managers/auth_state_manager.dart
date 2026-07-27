import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gostylens/core/config/dependency_injection.dart';
import 'package:gostylens/core/services/api_service/index.dart';
import 'package:gostylens/core/services/analytics_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:gostylens/utils/auth_utils.dart';
import 'package:gostylens/core/managers/push_notification_manager.dart';
import 'package:gostylens/core/managers/user_state_manager.dart';

class AuthStateManager extends ChangeNotifier {
  final supabase = locator<SupabaseClient>();
  final UserApiService _userApiService = locator<UserApiService>();
  final AnalyticsService _analyticsService = locator<AnalyticsService>();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  int _resendOTPSeconds = 60;
  int get resendOTPSeconds => _resendOTPSeconds;

  bool _canResendOTP = false;
  bool get canResendOTP => _canResendOTP;

  String? _lastEmailSent;
  Timer? _otpResendTimer;

  Future<void> initiateLoginWithOtp(
    String email, {
    void Function()? onSuccess,
    void Function(String error)? onError,
  }) async {
    if (!_canResendOTP &&
        _lastEmailSent == email &&
        _otpResendTimer != null &&
        _otpResendTimer!.isActive) {
      // Smart Throttle: We are still actively counting down for this exact email.
      // Don't send a new OTP and don't reset the timer. Just proceed to verify screen.
      onSuccess?.call();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      await supabase.auth.signInWithOtp(email: email);
      _lastEmailSent = email;
      _startResendOTPTimer();
      onSuccess?.call();
    } catch (e, stackTrace) {
      _analyticsService.captureException(e, stackTrace: stackTrace);

      _analyticsService.capture(
        'auth_error',
        properties: {
          'method': 'otp',
          'error_code': AuthUtils.getAuthErrorCode(e),
        },
      );

      final friendlyError = AuthUtils.parseAuthError(e);

      onError?.call(
        friendlyError ?? 'Error trying to log in. Please try again.',
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> verifyOTP(
    String email,
    String otp, {
    OtpType type = OtpType.email,
    void Function(bool isNewUser)? onSuccess,
    void Function(String error)? onError,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await supabase.auth.verifyOTP(
        email: email,
        token: otp,
        type: type,
      );

      if (response.user != null) {
        // Check if user exists in the backend API
        final userResponse = await _userApiService.getUserByAuthId(
          response.user!.id,
        );

        if (userResponse.isSuccess) {
          // User exists, they are not new
          _analyticsService.identify(
            response.user!.id,
            properties: {'email': email, 'auth_method': 'otp'},
          );
          onSuccess?.call(false);
        } else if (userResponse.statusCode == 404 ||
            userResponse.error?.code == 'NOT_FOUND' ||
            userResponse.error?.code == "STYLENS_USER_NOT_FOUND") {
          // User explicitly not found, they are a brand new user
          _analyticsService.identify(
            response.user!.id,
            properties: {
              'email': email,
              'auth_method': 'otp',
              'is_new_user': true,
            },
          );
          onSuccess?.call(true);
        } else {
          throw userResponse.error!;
        }
      }
    } catch (e, stackTrace) {
      _analyticsService.captureException(e, stackTrace: stackTrace);

      _analyticsService.capture(
        'auth_error',
        properties: {
          'method': 'otp_verify',
          'error_code': AuthUtils.getAuthErrorCode(e),
        },
      );

      final friendlyError = AuthUtils.parseAuthError(e);
      onError?.call(
        friendlyError ?? 'Error trying to verify OTP. Please try again.',
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _startResendOTPTimer() {
    _canResendOTP = false;
    _resendOTPSeconds = 60;
    notifyListeners();

    _otpResendTimer?.cancel();
    _otpResendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendOTPSeconds > 0) {
        _resendOTPSeconds--;
        notifyListeners();
      } else {
        _canResendOTP = true;
        notifyListeners();
        timer.cancel();
      }
    });
  }

  Future<void> logOut({
    void Function()? onSuccess,
    void Function(String error)? onError,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Unregister push notifications token on logout
      try {
        await locator<PushNotificationManager>().unregisterToken();
      } catch (e) {
        print('Error unregistering push token during logout: $e');
      }

      await supabase.auth.signOut();
      _analyticsService.reset();
      onSuccess?.call();
    } catch (e) {
      onError?.call(e.toString());
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signInWithGoogle({
    void Function(bool isNewUser, {String? email, String? name})? onSuccess,
    void Function(String error)? onError,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final googleUser = await locator<GoogleSignIn>().authenticate();
      final idToken = googleUser.authentication.idToken;

      if (idToken == null) {
        throw 'No ID token found from Google Sign-In.';
      }

      final response = await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );

      if (response.user != null) {
        final googleEmail = googleUser.email.trim();
        final googleName = googleUser.displayName?.trim();
        final resolvedName = (googleName != null && googleName.isNotEmpty)
            ? googleName
            : null;
        final resolvedEmail = googleEmail.isNotEmpty ? googleEmail : null;

        // Write draft early to beat AuthFlow redirect race to OnboardingName,
        // and persist to user_metadata so onboarding can recover after relaunch.
        if (resolvedName != null || resolvedEmail != null) {
          locator<UserStateManager>().updateRegistrationDraft(
            email: resolvedEmail,
            name: resolvedName,
          );
          await supabase.auth.updateUser(
            UserAttributes(
              data: {
                if (resolvedName != null) ...{
                  'name': resolvedName,
                  'full_name': resolvedName,
                },
                'email': ?resolvedEmail,
              },
            ),
          );
        }

        // Check if user exists in the backend API
        final userResponse = await _userApiService.getUserByAuthId(
          response.user!.id,
        );

        if (userResponse.isSuccess) {
          // User exists, they are not new
          _analyticsService.identify(
            response.user!.id,
            properties: {
              'email': resolvedEmail ?? '',
              'name': resolvedName ?? '',
              'auth_method': 'google',
            },
          );
          onSuccess?.call(false);
        } else if (userResponse.statusCode == 404) {
          // User explicitly not found, they are a brand new user
          _analyticsService.identify(
            response.user!.id,
            properties: {
              'email': resolvedEmail ?? '',
              'name': resolvedName ?? '',
              'auth_method': 'google',
              'is_new_user': true,
            },
          );
          onSuccess?.call(true, email: resolvedEmail, name: resolvedName);
        } else {
          // It failed for some other reason (500 Server Error, Network, etc.)
          onError?.call('Failed to verify user profile: ${userResponse.error}');
        }
      }
    } catch (e) {
      final friendlyError = AuthUtils.parseAuthError(e);

      // --- Analytics Tracking ---
      _analyticsService.capture(
        'auth_error',
        properties: {
          'provider': 'google',
          'is_canceled': e is GoogleSignInException && e.isCanceled,
          'error_code': e is GoogleSignInException
              ? e.technicalCode
              : 'unknown',
          'raw_error': e.toString(),
        },
      );

      if (friendlyError != null) {
        _analyticsService.captureException(e);
        onError?.call(friendlyError);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signInWithApple({
    void Function(bool isNewUser, {String? email, String? name})? onSuccess,
    void Function(String error)? onError,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final rawNonce = supabase.auth.generateRawNonce();
      final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      final idToken = credential.identityToken;
      if (idToken == null) {
        throw 'No identity token found.';
      }

      final response = await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      );

      if (response.user != null) {
        // Apple only returns name/email on first authorization — capture immediately.
        // Prefer givenName for "What should we call you?"; fall back to full name.
        final appleEmail = credential.email;
        final givenName = credential.givenName?.trim();
        final familyName = credential.familyName?.trim();
        final fullName = [
          givenName,
          familyName,
        ].whereType<String>().where((part) => part.isNotEmpty).join(' ');
        final resolvedName = (givenName != null && givenName.isNotEmpty)
            ? givenName
            : (fullName.isEmpty ? null : fullName);

        // Write draft early to beat AuthFlow redirect race to OnboardingName,
        // and persist to user_metadata so onboarding can recover after relaunch
        // (and so _extractMetadataFromSupabase can find it).
        if (resolvedName != null ||
            (appleEmail != null && appleEmail.isNotEmpty)) {
          locator<UserStateManager>().updateRegistrationDraft(
            email: appleEmail,
            name: resolvedName,
          );
          await supabase.auth.updateUser(
            UserAttributes(
              data: {
                'name': ?resolvedName,
                if (fullName.isNotEmpty) 'full_name': fullName,
                if (appleEmail != null && appleEmail.isNotEmpty)
                  'email': appleEmail,
              },
            ),
          );
        }

        // Check if user exists in the backend API
        final userResponse = await _userApiService.getUserByAuthId(
          response.user!.id,
        );

        if (userResponse.isSuccess) {
          // User exists, they are not new
          _analyticsService.identify(
            response.user!.id,
            properties: {
              'email': appleEmail ?? '',
              'name': resolvedName ?? '',
              'auth_method': 'apple',
            },
          );
          onSuccess?.call(false);
        } else if (userResponse.statusCode == 404) {
          // User explicitly not found, they are a brand new user
          _analyticsService.identify(
            response.user!.id,
            properties: {
              'email': appleEmail ?? '',
              'name': resolvedName ?? '',
              'auth_method': 'apple',
              'is_new_user': true,
            },
          );
          onSuccess?.call(true, email: appleEmail, name: resolvedName);
        } else {
          // It failed for some other reason (500 Server Error, Network, etc.)
          onError?.call('Failed to verify user profile: ${userResponse.error}');
        }
      }
    } catch (e) {
      final friendlyError = AuthUtils.parseAuthError(e);

      // --- Analytics Tracking ---
      _analyticsService.capture(
        'auth_error',
        properties: {
          'provider': 'apple',
          'is_canceled': e is SignInWithAppleException && e.isCanceled,
          'error_code': e is SignInWithAppleException
              ? (e.technicalCode ?? 'unknown')
              : 'unknown',
          'raw_error': e.toString(),
        },
      );

      if (friendlyError != null) {
        _analyticsService.captureException(e);
        onError?.call(friendlyError);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _otpResendTimer?.cancel();
    super.dispose();
  }
}
