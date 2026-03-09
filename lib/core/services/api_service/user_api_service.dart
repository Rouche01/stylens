import './base_api_service.dart';
import 'package:gostylens/models/api_responses/api_response.dart';
import 'package:gostylens/models/api_responses/user.dart';

class UserApiService extends BaseApiService {
  UserApiService() : super(resourcePath: 'users');

  /// Fetches a user from the database by their Auth ID.
  Future<ApiResponse<User>> getUserByAuthId(String authId) async {
    return get<User>(
      '/auth/$authId',
      fromJson: (data) => User.fromJson(data),
      defaultErrorMessage: 'User not found or error occurred',
    );
  }

  /// Creates a new user in the database.
  Future<ApiResponse<User>> createUser({
    required String authId,
    required String name,
    required String? gender,
    String? email,
  }) async {
    final requestBody = {
      'authId': authId,
      'name': name,
      if (gender != null) 'gender': gender,
      if (email != null) 'email': email,
    };

    return post<User>(
      '',
      body: requestBody,
      fromJson: (data) => User.fromJson(data),
      defaultErrorMessage: 'Failed to create user',
    );
  }
}
