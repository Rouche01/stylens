import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gostylens/core/config/dependency_injection.dart';
import 'package:gostylens/core/navigation/app_navigation_keys.dart';
import 'package:gostylens/core/navigation/deep_link/deep_link_parser.dart';
import 'package:gostylens/core/navigation/deep_link/deep_link_service.dart';
import 'package:gostylens/navigation/app_router.dart';
import 'package:gostylens/widgets/in_app_notification_snackbar.dart';

class ForegroundNotificationHandler {
  ForegroundNotificationHandler({
    DeepLinkParser? parser,
    DeepLinkService? deepLinkService,
  }) : _parser = parser ?? locator<DeepLinkParser>(),
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
    final text = _messageText(message);
    if (text == null || text.isEmpty) {
      return false;
    }

    final destination = _parser.parsePushData(message.data);
    if (isViewingDestination(destination)) {
      return false;
    }

    return true;
  }

  void _showInAppSnackBar(RemoteMessage message) {
    final messenger = rootScaffoldMessengerKey.currentState;
    if (messenger == null) {
      if (kDebugMode) {
        print(
          'Foreground notification skipped: scaffold messenger unavailable',
        );
      }
      return;
    }

    final body = _messageText(message);
    if (body == null || body.isEmpty) return;

    final data = message.data;
    final canOpen = _parser.canOpenFromPushData(data);
    final destination = _parser.parsePushData(data);
    final context = rootNavigatorKey.currentContext;

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        padding: EdgeInsets.zero,
        margin: InAppNotificationSnackBar.marginFor(context),
        duration: const Duration(seconds: 8),
        content: InAppNotificationSnackBar(
          body: body,
          actionLabel: canOpen ? actionLabelForDestination(destination) : null,
          onAction: canOpen
              ? () {
                  messenger.hideCurrentSnackBar();
                  _openDeepLink(data);
                }
              : null,
          onDismiss: messenger.hideCurrentSnackBar,
        ),
      ),
    );
  }

  void _openDeepLink(Map<String, dynamic> data) {
    _deepLinkService.handlePushData(data);
  }

  /// Body-first in-app copy; fall back to title when body is missing.
  String? _messageText(RemoteMessage message) {
    final body = _bodyFor(message);
    if (body != null && body.isNotEmpty) return body;
    final title = _titleFor(message);
    if (title != null && title.isNotEmpty) return title;
    return null;
  }

  String? _titleFor(RemoteMessage message) =>
      message.notification?.title ?? message.data['title'];

  String? _bodyFor(RemoteMessage message) =>
      message.notification?.body ?? message.data['body'];
}
