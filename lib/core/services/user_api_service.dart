import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:gostylens/utils/api_utils.dart';
import 'package:http/http.dart' as http;
import 'package:gostylens/models/api_responses/api_response.dart';
import 'package:gostylens/models/api_responses/user.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

class UserApiService {
  String get _baseUrl => dotenv.env['API_BASE_URL'] ?? '';

  Future<Map<String, String>> get _headers async {
    final session = supabase.Supabase.instance.client.auth.currentSession;
    final token = session?.accessToken;

    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Fetches a user from the database by their Auth ID.
  Future<ApiResponse<User>> getUserByAuthId(String authId) async {
    try {
      final headers = await _headers;
      final response = await http.get(
        Uri.parse('$_baseUrl/users/auth/$authId'),
        headers: headers,
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
      return ApiResponse(
        error: parseApiError('Network error', error: e),
        statusCode: -1,
      );
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

      final headers = await _headers;
      final response = await http.post(
        Uri.parse('$_baseUrl/users'),
        headers: headers,
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
          error: parseApiError('Failed to create user', response: response),
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse(
        error: parseApiError('Network error', error: e),
        statusCode: -1,
      );
    }
  }
}
