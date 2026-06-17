/// Tracks whether the user is currently viewing a style analysis chat screen.
class StyleAnalysisRouteTracker {
  String? _visibleSessionId;
  bool _isOnChatScreen = false;

  bool get isOnChatScreen => _isOnChatScreen;

  void setChatScreenVisible({
    required bool visible,
    String? sessionId,
  }) {
    _isOnChatScreen = visible;
    _visibleSessionId = visible ? sessionId : null;
  }

  void updateVisibleSession(String? sessionId) {
    if (_isOnChatScreen) {
      _visibleSessionId = sessionId;
    }
  }

  bool isViewingSession(String sessionId) =>
      _isOnChatScreen &&
      _visibleSessionId != null &&
      _visibleSessionId == sessionId;
}
