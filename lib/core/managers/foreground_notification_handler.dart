import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gostylens/core/config/dependency_injection.dart';
import 'package:gostylens/core/managers/style_analysis_session/index.dart';
import 'package:gostylens/core/navigation/app_navigation_keys.dart';
import 'package:gostylens/core/navigation/style_analysis_route_tracker.dart';
import 'package:gostylens/pages/style_analysis.dart';

/// Known `data.type` values sent by the backend.
abstract final class PushNotificationTypes {
  static const styleAdviceReady = 'style_advice_ready';
}

class ForegroundNotificationHandler {
  ForegroundNotificationHandler({
    StyleAnalysisRouteTracker? routeTracker,
  }) : _routeTracker = routeTracker ?? locator<StyleAnalysisRouteTracker>();

  final StyleAnalysisRouteTracker _routeTracker;

  void handle(RemoteMessage message) {
    if (!_shouldShow(message)) {
      if (kDebugMode) {
        print('Foreground notification suppressed: ${message.data}');
      }
      return;
    }

    _showInAppSnackBar(message);
  }

  bool _shouldShow(RemoteMessage message) {
    final title = _titleFor(message);
    final body = _bodyFor(message);
    if ((title == null || title.isEmpty) && (body == null || body.isEmpty)) {
      return false;
    }

    final type = message.data['type'] ?? message.data['notification_type'];
    final sessionId =
        message.data['session_id'] ?? message.data['sessionId'];

    if (type == PushNotificationTypes.styleAdviceReady &&
        sessionId != null &&
        sessionId.isNotEmpty &&
        _routeTracker.isViewingSession(sessionId)) {
      return false;
    }

    return true;
  }

  void _showInAppSnackBar(RemoteMessage message) {
    final messenger = rootScaffoldMessengerKey.currentState;
    if (messenger == null) return;

    final title = _titleFor(message);
    final body = _bodyFor(message);
    final sessionId =
        message.data['session_id'] ?? message.data['sessionId'];
    final canOpenSession = sessionId != null && sessionId.isNotEmpty;

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        content: _NotificationSnackBarContent(title: title, body: body),
        action: canOpenSession
            ? SnackBarAction(
                label: 'Open',
                onPressed: () => _openStyleAnalysisSession(sessionId),
              )
            : null,
      ),
    );
  }

  void _openStyleAnalysisSession(String sessionId) {
    final navigator = rootNavigatorKey.currentState;
    if (navigator == null) return;

    locator<StyleAnalysisSessionManager>().setSelectedSessionId(sessionId);
    navigator.push(
      MaterialPageRoute(builder: (_) => const StyleAnalysisPage()),
    );
  }

  String? _titleFor(RemoteMessage message) =>
      message.notification?.title ?? message.data['title'];

  String? _bodyFor(RemoteMessage message) =>
      message.notification?.body ?? message.data['body'];
}

class _NotificationSnackBarContent extends StatelessWidget {
  const _NotificationSnackBarContent({this.title, this.body});

  final String? title;
  final String? body;

  @override
  Widget build(BuildContext context) {
    final hasTitle = title != null && title!.isNotEmpty;
    final hasBody = body != null && body!.isNotEmpty;

    if (hasTitle && hasBody) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title!, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(body!),
        ],
      );
    }

    return Text(title ?? body ?? '');
  }
}
