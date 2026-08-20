import 'package:flutter_test/flutter_test.dart';
import 'package:gostylens/models/api_responses/api_response.dart';
import 'package:gostylens/models/style_analysis_session_message_error.dart';
import 'package:gostylens/utils/api_utils.dart';
import 'package:gostylens/utils/string_extensions.dart';

void main() {
  group('ErrorData', () {
    test('toString returns the friendly message, not Instance of ErrorData', () {
      final error = ErrorData(
        code: 'UNKNOWN',
        message: 'Session could not be created.',
      );

      expect(error.toString(), 'Session could not be created.');
      expect(error.toString(), isNot(contains("Instance of")));
    });

    test('toFriendlyMessage maps ngrok codes', () {
      final error = ErrorData(code: 'ERR_NGROK_3200', message: 'tunnel down');

      expect(
        error.toFriendlyMessage(),
        contains('server is currently offline'),
      );
    });

    test('toFriendlyMessage maps known backend code', () {
      final error = ErrorData(
        code: 'FREE_LIMIT_REACHED',
        message: 'quota exceeded',
      );

      expect(
        error.toFriendlyMessage(),
        'Free limit reached. Please upgrade to a Core plan for unlimited sessions.',
      );
    });

    test('toFriendlyMessage hides technical message for unknown coded error', () {
      final error = ErrorData(
        code: 'SOME_NEW_BACKEND_CODE',
        message: 'SOME_NEW_BACKEND_CODE',
      );

      expect(
        error.toFriendlyMessage(),
        'Oops! Something went wrong. If this persists, please contact support.',
      );
    });
  });

  group('friendlyErrorMessage', () {
    test('unwraps ErrorData', () {
      final error = ErrorData(
        code: 'NETWORK_ERROR',
        message: 'Connection failed. Please check your internet connection and try again.',
      );

      expect(friendlyErrorMessage(error), error.toFriendlyMessage());
    });

    test('strips Exception wrapping an ErrorData message', () {
      final error = ErrorData(
        code: 'UNKNOWN',
        message: 'Failed to add message',
      );

      expect(
        friendlyErrorMessage(Exception(error)),
        'Failed to add message',
      );
    });
  });

  group('StyleAnalysisSessionMessageError.fromCaughtError', () {
    test('uses ErrorData message and code', () {
      final caught = StyleAnalysisSessionMessageError.fromCaughtError(
        ErrorData(code: 'FREE_LIMIT_REACHED', message: 'Upgrade to continue.'),
      );

      expect(
        caught.message,
        'Free limit reached. Please upgrade to a Core plan for unlimited sessions.',
      );
      expect(caught.type, MessageErrorType.freeLimitReached);
    });

    test('does not prefix Exception or Instance of', () {
      final caught = StyleAnalysisSessionMessageError.fromCaughtError(
        Exception(
          ErrorData(code: 'UNKNOWN', message: 'Unable to create session.'),
        ),
      );

      expect(caught.message, 'Unable to create session.');
      expect(caught.message, isNot(contains('Exception')));
      expect(caught.message, isNot(contains("Instance of")));
    });

    test('maps backend code aliases to error type', () {
      final caught = StyleAnalysisSessionMessageError.fromCaughtError(
        ErrorData(code: 'MESSAGE_LIMIT_REACHED', message: 'limit reached'),
      );

      expect(caught.type, MessageErrorType.freeLimitReached);
    });
  });

  group('cleanException', () {
    test('strips nested Exception prefixes', () {
      expect(
        'Exception: Exception: boom'.cleanException(),
        'boom',
      );
    });
  });
}
