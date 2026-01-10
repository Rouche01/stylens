import 'package:gostylens/models/api_responses/pagination_info.dart';
import 'package:gostylens/models/style_analysis_session.dart';

class StyleAnalysisSessionsResponse {
  final List<StyleAnalysisSession> sessions;
  final PaginationInfo pagination;

  StyleAnalysisSessionsResponse({
    required this.sessions,
    required this.pagination,
  });

  factory StyleAnalysisSessionsResponse.fromJson(Map<String, dynamic> json) {
    var sessionsJson = json['sessions'] as List<dynamic>;
    List<StyleAnalysisSession> sessionsList = sessionsJson
        .map((sessionJson) => StyleAnalysisSession.fromJson(sessionJson))
        .toList();

    return StyleAnalysisSessionsResponse(
      sessions: sessionsList,
      pagination: PaginationInfo.fromJson(json['pagination']),
    );
  }
}
