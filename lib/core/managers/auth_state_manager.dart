import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gostylens/core/config/dependency_injection.dart';
import 'package:gostylens/core/services/api_service/index.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthStateManager extends ChangeNotifier {
  final supabase = locator<SupabaseClient>();
  final UserApiService _userApiService = locator<UserApiService>();

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
    } catch (e) {
      onError?.call(e.toString());
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
          onSuccess?.call(false);
        } else if (userResponse.statusCode == 404) {
          // User explicitly not found, they are a brand new user
          onSuccess?.call(true);
        } else {
          // It failed for some other reason (500 Server Error, Network, etc.)
          onError?.call('Failed to verify user profile: ${userResponse.error}');
        }
      }
    } catch (e) {
      onError?.call(e.toString());
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
      await supabase.auth.signOut();
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
        final googleEmail = googleUser.email;
        final googleName = googleUser.displayName;

        // Check if user exists in the backend API
        final userResponse = await _userApiService.getUserByAuthId(
          response.user!.id,
        );

        if (userResponse.isSuccess) {
          // User exists, they are not new
          onSuccess?.call(false);
        } else if (userResponse.statusCode == 404) {
          // User explicitly not found, they are a brand new user
          onSuccess?.call(true, email: googleEmail, name: googleName);
        } else {
          // It failed for some other reason (500 Server Error, Network, etc.)
          onError?.call('Failed to verify user profile: ${userResponse.error}');
        }
      }
    } catch (e) {
      onError?.call(e.toString());
      print('Error signing in with Google: $e');
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
        // Extract name and email from Apple credential if available
        final appleEmail = credential.email;
        final appleName = credential.givenName;

        // Check if user exists in the backend API
        final userResponse = await _userApiService.getUserByAuthId(
          response.user!.id,
        );

        if (userResponse.isSuccess) {
          // User exists, they are not new
          onSuccess?.call(false);
        } else if (userResponse.statusCode == 404) {
          // User explicitly not found, they are a brand new user
          onSuccess?.call(true, email: appleEmail, name: appleName);
        } else {
          // It failed for some other reason (500 Server Error, Network, etc.)
          onError?.call('Failed to verify user profile: ${userResponse.error}');
        }
      }
    } catch (e) {
      onError?.call(e.toString());
      print('Error signing in with Apple: $e');
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
