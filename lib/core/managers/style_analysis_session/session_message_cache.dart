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

/// In-memory LRU cache of session messages keyed by session id.
class SessionMessageCache {
  SessionMessageCache({this.maxSize = 10});

  final int maxSize;

  final Map<String, SessionMessageCacheEntry> _entries = {};
  final List<String> _accessOrder = [];

  bool contains(String sessionId) {
    final entry = _entries[sessionId];
    return entry != null && entry.messages.isNotEmpty;
  }

  SessionMessageCacheEntry? get(String sessionId) {
    final entry = _entries[sessionId];
    if (entry == null) return null;
    _touchAccess(sessionId);
    return entry;
  }

  void put(String sessionId, SessionMessageCacheEntry entry) {
    _entries[sessionId] = entry;
    _touchAccess(sessionId);
    _evictOldestIfNeeded();
  }

  void clear() {
    _entries.clear();
    _accessOrder.clear();
  }

  void _touchAccess(String sessionId) {
    _accessOrder.remove(sessionId);
    _accessOrder.add(sessionId);
  }

  void _evictOldestIfNeeded() {
    while (_accessOrder.length > maxSize) {
      final evictId = _accessOrder.removeAt(0);
      _entries.remove(evictId);
    }
  }
}
