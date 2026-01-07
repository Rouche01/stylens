import 'package:stylens_app/models/api_responses/pagination_info.dart';
import 'package:stylens_app/models/style_analysis_session_message.dart';

class SessionMessagesResponse {
  final String sessionId;
  final String sessionTitle;
  final String userId;
  final List<StyleAnalysisSessionMessage> messages;
  final PaginationInfo pagination;

  SessionMessagesResponse({
    required this.sessionId,
    required this.sessionTitle,
    required this.userId,
    required this.messages,
    required this.pagination,
  });

  factory SessionMessagesResponse.fromJson(Map<String, dynamic> json) {
    final messagesJson = json['messages'] as List<dynamic>? ?? [];

    return SessionMessagesResponse(
      sessionId: json['sessionId'],
      sessionTitle: json['sessionTitle'],
      userId: json['userId'],
      messages: messagesJson
          .map(
            (msg) => StyleAnalysisSessionMessage.fromJson(
              msg as Map<String, dynamic>,
            ),
          )
          .toList(),
      pagination: PaginationInfo.fromJson(json['pagination']),
    );
  }
}
