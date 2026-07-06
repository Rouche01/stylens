import 'package:gostylens/models/api_responses/pagination_info.dart';
import 'package:gostylens/models/style_analysis_session_message.dart';

class SessionMessageCacheEntry {
  final List<StyleAnalysisSessionMessage> messages;
  final PaginationInfo? pagination;
  final DateTime cachedAt;

  const SessionMessageCacheEntry({
    required this.messages,
    this.pagination,
    required this.cachedAt,
  });
}
