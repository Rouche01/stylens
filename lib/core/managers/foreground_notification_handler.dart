import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gostylens/core/config/dependency_injection.dart';
import 'package:gostylens/core/navigation/app_navigation_keys.dart';
import 'package:gostylens/core/navigation/deep_link/deep_link_destination.dart';
import 'package:gostylens/core/navigation/deep_link/deep_link_parser.dart';
import 'package:gostylens/core/navigation/deep_link/deep_link_service.dart';
import 'package:gostylens/navigation/app_router.dart';

class ForegroundNotificationHandler {
  ForegroundNotificationHandler({
    DeepLinkParser? parser,
    DeepLinkService? deepLinkService,
  })  : _parser = parser ?? locator<DeepLinkParser>(),
        _deepLinkService = deepLinkService ?? locator<DeepLinkService>();

  final DeepLinkParser _parser;
  final DeepLinkService _deepLinkService;

  void handle(RemoteMessage message) {
    if (kDebugMode) {
      print('Foreground notification received: ${message.data}');
    }
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

    final destination = _parser.parsePushData(message.data);
    if (destination.target == DeepLinkTarget.session) {
      final sessionId = destination.sessionId;
      if (sessionId != null &&
          sessionId.isNotEmpty &&
          isViewingSession(sessionId)) {
        return false;
      }
    }

    return true;
  }

  void _showInAppSnackBar(RemoteMessage message) {
    final messenger = rootScaffoldMessengerKey.currentState;
    if (messenger == null) {
      if (kDebugMode) {
        print('Foreground notification skipped: scaffold messenger unavailable');
      }
      return;
    }

    final title = _titleFor(message);
    final body = _bodyFor(message);
    final canOpen = _parser.canOpenFromPushData(message.data);

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        content: _NotificationSnackBarContent(title: title, body: body),
        action: canOpen
            ? SnackBarAction(
                label: 'Open',
                onPressed: () => _openDeepLink(message.data),
              )
            : null,
      ),
    );
  }

  void _openDeepLink(Map<String, dynamic> data) {
    _deepLinkService.handlePushData(data);
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
