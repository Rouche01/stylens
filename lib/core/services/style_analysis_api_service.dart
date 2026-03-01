import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:gostylens/models/api_responses/session_messages_response.dart';
import 'package:gostylens/models/api_responses/style_analysis_sessions_response.dart';
import 'package:gostylens/models/api_responses/paginated_response.dart';
import 'package:gostylens/models/style_analysis_session.dart';
import 'package:gostylens/models/style_analysis_session_message.dart';
import 'package:gostylens/models/api_responses/api_response.dart';

class StyleAnalysisApiService {
  final String userId;

  StyleAnalysisApiService({required this.userId});

  String get _baseUrl => dotenv.env['API_BASE_URL'] ?? '';

  Map<String, String> get _headers => {'Content-Type': 'application/json'};

  // --- Sessions ---
  Future<ApiResponse<PaginatedResponse<StyleAnalysisSession>>> fetchSessions({
    int page = 1,
    int pageSize = 10,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$_baseUrl/style-analysis/sessions?userId=$userId&page=$page&pageSize=$pageSize',
        ),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final sessionsResponse = StyleAnalysisSessionsResponse.fromJson(
          responseData,
        );
        final sessions = sessionsResponse.sessions;

        return ApiResponse(
          data: PaginatedResponse(
            items: sessions,
            pagination: sessionsResponse.pagination,
          ),
          statusCode: response.statusCode,
        );
      }

      return ApiResponse(
        error: 'Failed to load sessions: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ApiResponse(error: 'Network error: $e', statusCode: -1);
    }
  }

  Future<ApiResponse<String>> createSession({
    required List<Map<String, dynamic>> messages,
  }) async {
    try {
      final requestBody = {'userId': userId, 'messages': messages};

      final response = await http.post(
        Uri.parse('$_baseUrl/style-analysis/sessions'),
        headers: _headers,
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = json.decode(response.body);
        final sessionId = responseData['sessionId'] ?? responseData['id'];
        return ApiResponse(data: sessionId, statusCode: response.statusCode);
      }

      return ApiResponse(
        error:
            'Failed to create session: ${response.statusCode} - ${response.body}',
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ApiResponse(error: 'Failed to create session: $e', statusCode: -1);
    }
  }

  Future<ApiResponse<void>> deleteSession(String sessionId) async {
    try {
      final response = await http.delete(
        Uri.parse(
          '$_baseUrl/style-analysis/sessions/$sessionId?userId=$userId',
        ),
        headers: _headers,
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        return ApiResponse(statusCode: response.statusCode);
      }

      return ApiResponse(
        error: 'Failed to delete session: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ApiResponse(error: 'Failed to delete session: $e', statusCode: -1);
    }
  }

  // --- Messages ---
  Future<ApiResponse<PaginatedResponse<StyleAnalysisSessionMessage>>>
  fetchSessionMessages(
    String sessionId, {
    int page = 1,
    int pageSize = 10,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$_baseUrl/style-analysis/sessions/$sessionId/messages?userId=$userId&page=$page&pageSize=$pageSize',
        ),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final sessionMessagesResponse = SessionMessagesResponse.fromJson(
          responseData,
        );

        return ApiResponse(
          data: PaginatedResponse(
            items: sessionMessagesResponse.messages,
            pagination: sessionMessagesResponse.pagination,
          ),
          statusCode: response.statusCode,
        );
      }

      return ApiResponse(
        error: 'Failed to load messages: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ApiResponse(error: 'Failed to fetch messages: $e', statusCode: -1);
    }
  }

  Future<ApiResponse<void>> addMessageToSession({
    required String sessionId,
    required Map<String, dynamic> message,
  }) async {
    try {
      final requestBody = {'userId': userId, 'message': message};

      final response = await http.post(
        Uri.parse('$_baseUrl/style-analysis/sessions/$sessionId/messages'),
        headers: _headers,
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return ApiResponse(statusCode: response.statusCode);
      }

      return ApiResponse(
        error:
            'Failed to add message: ${response.statusCode} - ${response.body}',
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ApiResponse(error: 'Failed to add message: $e', statusCode: -1);
    }
  }

  // --- Streaming ---
  Future<http.StreamedResponse> streamAssistantResponse({
    required String sessionId,
    required String contextMode,
  }) async {
    final request = http.Request(
      'GET',
      Uri.parse(
        '$_baseUrl/style-analysis/sessions/$sessionId/stream?userId=$userId&contextMode=$contextMode',
      ),
    );

    request.headers['Content-Type'] = 'application/json';
    request.headers['Accept'] = 'text/event-stream';

    return await request.send();
  }
}
