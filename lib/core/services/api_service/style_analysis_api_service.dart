import './base_api_service.dart';
import 'package:http/http.dart' as http;
import 'package:gostylens/models/api_responses/session_messages_response.dart';
import 'package:gostylens/models/api_responses/style_analysis_sessions_response.dart';
import 'package:gostylens/models/api_responses/paginated_response.dart';
import 'package:gostylens/models/style_analysis_session.dart';
import 'package:gostylens/models/style_analysis_session_message.dart';
import 'package:gostylens/models/api_responses/api_response.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:gostylens/core/config/dependency_injection.dart';

class StyleAnalysisApiService extends BaseApiService {
  StyleAnalysisApiService() : super(resourcePath: 'style-analysis/sessions/');

  // --- Sessions ---
  Future<ApiResponse<PaginatedResponse<StyleAnalysisSession>>> fetchSessions({
    int page = 1,
    int pageSize = 10,
    bool? isFavourite,
  }) async {
    String path = '?page=$page&pageSize=$pageSize';
    if (isFavourite != null) path += '&is_favourite=$isFavourite';

    return get<PaginatedResponse<StyleAnalysisSession>>(
      path,
      fromJson: (data) {
        final sessionsResponse = StyleAnalysisSessionsResponse.fromJson(data);
        return PaginatedResponse(
          items: sessionsResponse.sessions,
          pagination: sessionsResponse.pagination,
        );
      },
      defaultErrorMessage: 'Failed to load sessions',
    );
  }

  Future<ApiResponse<String>> createSession({
    required List<Map<String, dynamic>> messages,
  }) async {
    return post<String>(
      '',
      body: {'messages': messages},
      fromJson: (data) => data['sessionId'] ?? data['id'],
      defaultErrorMessage: 'Failed to create session',
    );
  }

  Future<ApiResponse<void>> deleteSession(String sessionId) async {
    return delete<void>(
      sessionId,
      defaultErrorMessage: 'Failed to delete session',
    );
  }

  // --- Messages ---
  Future<ApiResponse<PaginatedResponse<StyleAnalysisSessionMessage>>>
  fetchSessionMessages(
    String sessionId, {
    int page = 1,
    int pageSize = 10,
  }) async {
    return get<PaginatedResponse<StyleAnalysisSessionMessage>>(
      '$sessionId/messages?page=$page&pageSize=$pageSize',
      fromJson: (data) {
        final sessionMessagesResponse = SessionMessagesResponse.fromJson(data);
        return PaginatedResponse(
          items: sessionMessagesResponse.messages,
          pagination: sessionMessagesResponse.pagination,
        );
      },
      defaultErrorMessage: 'Failed to load messages',
    );
  }

  Future<ApiResponse<void>> addMessageToSession({
    required String sessionId,
    required Map<String, dynamic> message,
  }) async {
    return post<void>(
      '$sessionId/messages',
      body: {'message': message},
      defaultErrorMessage: 'Failed to add message',
    );
  }

  Future<ApiResponse<void>> toggleFavorite(
    String sessionId,
    bool isFavorite,
  ) async {
    return patch<void>(
      '$sessionId/favourite',
      body: {'isFavourite': isFavorite},
      defaultErrorMessage: 'Failed to update favorite status',
    );
  }

  Future<ApiResponse<void>> updateSessionProperties(
    String sessionId,
    Map<String, dynamic> properties,
  ) async {
    return patch<void>(
      sessionId,
      body: properties,
      defaultErrorMessage: 'Failed to update session',
    );
  }

  // --- Streaming ---
  Future<http.StreamedResponse> streamAssistantResponse({
    required String sessionId,
    required String contextMode,
  }) async {
    final request = http.Request(
      'GET',
      Uri.parse(buildUrl('$sessionId/stream?contextMode=$contextMode')),
    );

    request.headers['Content-Type'] = 'application/json';
    request.headers['Accept'] = 'text/event-stream';

    final session = locator<supabase.SupabaseClient>().auth.currentSession;
    if (session?.accessToken != null) {
      request.headers['Authorization'] = 'Bearer ${session!.accessToken}';
    }

    return await request.send();
  }
}
