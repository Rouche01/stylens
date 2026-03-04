import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gostylens/core/services/user_api_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthStateManager extends ChangeNotifier {
  final supabase = Supabase.instance.client;
  final UserApiService _userApiService = UserApiService();

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

  @override
  void dispose() {
    _otpResendTimer?.cancel();
    super.dispose();
  }
}
