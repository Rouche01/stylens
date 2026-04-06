import './base_api_service.dart';
import 'package:gostylens/models/api_responses/api_response.dart';
import 'package:gostylens/models/api_responses/user.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';

class UserApiService extends BaseApiService {
  UserApiService() : super(resourcePath: 'users');

  /// Fetches a user from the database by their Auth ID.
  Future<ApiResponse<User>> getUserByAuthId(String authId) async {
    return get<User>(
      '/auth/$authId',
      options: CacheOptions(
        store: MemCacheStore(),
        policy: CachePolicy.noCache,
      ).toOptions(),
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

  /// Updates an existing user in the database.
  Future<ApiResponse<User>> updateUser({
    required String userId,
    String? name,
    String? nickname,
    String? gender,
  }) async {
    final requestBody = {
      if (name != null) 'name': name,
      if (nickname != null) 'nickname': nickname,
      if (gender != null) 'gender': gender,
    };

    return patch<User>(
      '/$userId',
      body: requestBody,
      fromJson: (data) => User.fromJson(data),
      defaultErrorMessage: 'Failed to update user',
    );
  }

  Future<ApiResponse<void>> deleteUser(String userId) async {
    return delete<void>(
      '/$userId',
      defaultErrorMessage: 'Failed to delete user',
    );
  }
}
