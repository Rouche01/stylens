import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:gostylens/models/api_responses/api_response.dart';
import 'package:gostylens/models/api_responses/user.dart';

class UserApiService {
  String get _baseUrl => dotenv.env['API_BASE_URL'] ?? '';

  Map<String, String> get _headers => {'Content-Type': 'application/json'};

  /// Fetches a user from the database by their Auth ID.
  Future<ApiResponse<User>> getUserByAuthId(String authId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/users/auth/$authId'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return ApiResponse(
          data: User.fromJson(data),
          statusCode: response.statusCode,
        );
      } else {
        return ApiResponse(
          error: 'User not found or error occurred: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      print('Error fetching user: $e');
      return ApiResponse(error: 'Network error: $e', statusCode: -1);
    }
  }

  /// Creates a new user in the database.
  Future<ApiResponse<User>> createUser({
    required String authId,
    required String name,
    required String? gender,
    String? email,
  }) async {
    try {
      final requestBody = {
        'authId': authId,
        'name': name,
        if (gender != null) 'gender': gender,
        if (email != null) 'email': email,
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/users'),
        headers: _headers,
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        return ApiResponse(
          data: User.fromJson(data),
          statusCode: response.statusCode,
        );
      } else {
        return ApiResponse(
          error: 'Failed to create user: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      print('Error creating user: $e');
      return ApiResponse(error: 'Network error: $e', statusCode: -1);
    }
  }
}
