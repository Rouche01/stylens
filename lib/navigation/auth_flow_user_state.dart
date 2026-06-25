import 'package:flutter/foundation.dart';
import 'package:gostylens/models/api_responses/api_response.dart';
import 'package:gostylens/models/api_responses/user.dart';
import 'package:gostylens/models/user_state.dart';

/// Profile state surface required by [AuthFlowController].
abstract class AuthFlowUserState implements Listenable {
  UserOperationState get operationState;
  User? get currentUser;
  ErrorData? get lastError;

  Future<void> clearState();
  Future<void> fetchCurrentUser();
}
