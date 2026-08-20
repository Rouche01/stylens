import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/services.dart';
import 'package:gostylens/models/api_responses/api_response.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Extension to handle Google Sign-In exceptions gracefully.
extension GoogleSignInExceptionX on GoogleSignInException {
  /// Returns a user-friendly message based on the exception code.
  /// Returns null if the error should be handled silently (e.g. cancellation).
  String? get friendlyMessage {
    return switch (code) {
      GoogleSignInExceptionCode.canceled => null,
      GoogleSignInExceptionCode.userMismatch =>
        "This account doesn't match your previous sign-in. Please try your original account.",
      GoogleSignInExceptionCode.interrupted =>
        "The sign-in process was interrupted. Let's try that again.",
      GoogleSignInExceptionCode.uiUnavailable =>
        "We couldn't sign you in. Please try again.",
      GoogleSignInExceptionCode.clientConfigurationError ||
      GoogleSignInExceptionCode.providerConfigurationError =>
        "We're having trouble connecting to Google right now. Please try again in a moment or contact support if the error persists.",
      _ =>
        "We're having trouble connecting to Google right now. Please try again in a moment.",
    };
  }

  /// Returns true if the user cancelled the process.
  bool get isCanceled => code == GoogleSignInExceptionCode.canceled;

  /// Returns the technical name of the code for analytics.
  String get technicalCode => code.name;
}

extension SignInWithAppleExceptionX on SignInWithAppleException {
  /// Returns a user-friendly message based on the exception.
  /// Returns null if the error should be handled silently (e.g. cancellation).
  String? get friendlyMessage {
    final exception = this;
    if (exception is SignInWithAppleAuthorizationException) {
      return switch (exception.code) {
        AuthorizationErrorCode.canceled => null,
        AuthorizationErrorCode.failed ||
        AuthorizationErrorCode.notHandled ||
        AuthorizationErrorCode.invalidResponse ||
        AuthorizationErrorCode.notInteractive =>
          "We're having trouble connecting to Apple right now. Please try again in a moment or contact support if the error persists.",
        _ =>
          "We're having trouble connecting to Apple right now. Please try again in a moment.",
      };
    }

    if (exception is SignInWithAppleNotSupportedException) {
      return "We're having trouble connecting to Apple right now. Please try again in a moment.";
    }

    if (exception is SignInWithAppleCredentialsException) {
      return "We're having trouble connecting to Apple right now. Please try again in a moment.";
    }

    return "We're having trouble connecting to Apple right now. Please try again in a moment.";
  }

  /// Returns true if the user cancelled the process.
  bool get isCanceled {
    final exception = this;
    return exception is SignInWithAppleAuthorizationException &&
        exception.code == AuthorizationErrorCode.canceled;
  }

  /// Returns the technical name of the code for analytics.
  String? get technicalCode {
    final exception = this;
    if (exception is SignInWithAppleAuthorizationException) {
      return exception.code.name;
    }
    if (exception is SignInWithAppleNotSupportedException) {
      return 'not-supported';
    }

    if (exception is SignInWithAppleCredentialsException) {
      return 'credentials-error';
    }

    if (exception is UnknownSignInWithAppleException) {
      return 'unknown';
    }

    return null;
  }
}

extension AuthApiExceptionX on AuthApiException {
  String? get friendlyMessage {
    return message;
  }

  String? get technicalCode {
    return code;
  }
}

extension AuthRetryableFetchExceptionX on AuthRetryableFetchException {
  String? get friendlyMessage {
    if (code == "invalid_credentials") {
      return "Invalid email or password. Please try again.";
    }
    return "An error occurred during authentication. Please try again.";
  }

  String get technicalCode {
    return code ?? "unknown";
  }
}

extension ErrorDataX on ErrorData {
  String? get friendlyMessage {
    return toFriendlyMessage();
  }

  String? get technicalCode {
    return code;
  }
}

/// Utility class to parse various authentication errors.
class AuthUtils {
  /// Parses authentication errors into friendly messages.
  /// Returns null if the error should be ignored (e.g. user cancellation).
  static String? parseAuthError(dynamic error) {
    if (error is GoogleSignInException) {
      return error.friendlyMessage;
    }

    if (error is SignInWithAppleException) {
      return error.friendlyMessage;
    }

    if (error is AuthApiException) {
      return error.friendlyMessage;
    }

    if (error is AuthRetryableFetchException) {
      return error.friendlyMessage;
    }

    if (error is ErrorData) {
      return error.friendlyMessage;
    }

    if (error is PlatformException) {
      // Common codes for various auth plugins (Apple, Google, etc.)
      final code = error.code.toLowerCase();
      if (code.contains('canceled') ||
          code.contains('user_cancelled') ||
          code == 'com.apple.signindeviceerrordomain:1000') {
        return null;
      }

      return error.message ?? error.toString();
    }

    // Default fallback
    final errorStr = error.toString().toLowerCase();
    if (errorStr.contains('canceled') || errorStr.contains('cancelled')) {
      return null;
    }

    return error.toString();
  }

  static String getAuthErrorCode(dynamic error) {
    if (error is GoogleSignInException) {
      return error.technicalCode;
    }

    if (error is AuthRetryableFetchException) {
      return error.technicalCode;
    }

    if (error is ErrorData) {
      return error.technicalCode ?? "unknown";
    }

    if (error is AuthApiException) {
      return error.technicalCode ?? "unknown";
    }

    if (error is SignInWithAppleException) {
      return error.technicalCode ?? "unknown";
    }

    if (error is PlatformException) {
      return error.code;
    }

    return "unknown";
  }
}
