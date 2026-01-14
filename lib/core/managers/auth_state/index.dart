import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthStateManager extends ChangeNotifier {
  final supabase = Supabase.instance.client;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  int _resendOTPSeconds = 60;
  int get resendOTPSeconds => _resendOTPSeconds;

  bool _canResendOTP = false;
  bool get canResendOTP => _canResendOTP;

  Timer? _otpResendTimer;

  Future<void> initiateLoginWithOtp(
    String email, {
    void Function()? onSuccess,
    void Function(String error)? onError,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      await supabase.auth.signInWithOtp(email: email);
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
    void Function()? onSuccess,
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
        onSuccess?.call();
      } else {
        onError?.call('Invalid OTP or user not found.');
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

  @override
  void dispose() {
    _otpResendTimer?.cancel();
    super.dispose();
  }
}
