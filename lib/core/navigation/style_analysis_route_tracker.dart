/// Tracks whether the user is currently viewing a style analysis chat screen.
class StyleAnalysisRouteTracker {
  String? _visibleSessionId;

  void setVisibleSession(String? sessionId) {
    _visibleSessionId = sessionId;
  }

  bool isViewingSession(String sessionId) =>
      _visibleSessionId != null && _visibleSessionId == sessionId;
}
