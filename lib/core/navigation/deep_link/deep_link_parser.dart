import 'package:gostylens/core/navigation/deep_link/deep_link_destination.dart';
import 'package:gostylens/core/navigation/deep_link/push_notification_types.dart';

class DeepLinkParser {
  static const supportedScheme = 'gostylens';

  /// Returns null when [uri] is not a GoStylens deep link (e.g. Google OAuth).
  DeepLinkDestination? parseUri(Uri uri) {
    if (uri.scheme.toLowerCase() != supportedScheme) return null;

    var host = uri.host;
    var pathSegments = List<String>.from(uri.pathSegments);

    // Some platforms emit gostylens:/history (path-only) instead of gostylens://history.
    if (host.isEmpty && pathSegments.isEmpty && uri.path.isNotEmpty) {
      pathSegments = uri.path
          .split('/')
          .where((segment) => segment.isNotEmpty)
          .toList();
    }

    return _parseLocation(
      host: host,
      pathSegments: pathSegments,
      dest: uri.queryParameters['dest'],
      sessionId: uri.queryParameters['session_id'] ??
          uri.queryParameters['sessionId'],
    );
  }

  DeepLinkDestination parsePushData(Map<String, dynamic> data) {
    final explicitLink = data['link'] as String?;
    if (explicitLink != null && explicitLink.isNotEmpty) {
      final uri = Uri.tryParse(explicitLink);
      if (uri != null) {
        final destination = parseUri(uri);
        if (destination != null) return destination;
      }
    }

    final type = data['type'] ?? data['notification_type'];
    final sessionId = data['session_id'] ?? data['sessionId'];

    if (type == PushNotificationTypes.styleAdviceReady &&
        sessionId is String &&
        sessionId.isNotEmpty) {
      return DeepLinkDestination.session(sessionId);
    }

    return DeepLinkDestination.capture;
  }

  /// Whether [data] includes an explicit deep link or legacy routing fields.
  bool canOpenFromPushData(Map<String, dynamic> data) {
    if (hasExplicitLink(data)) return true;

    final destination = parsePushData(data);
    return destination.target != DeepLinkTarget.capture;
  }

  static bool hasExplicitLink(Map<String, dynamic> data) {
    final link = data['link'];
    return link is String && link.isNotEmpty;
  }

  DeepLinkDestination _parseLocation({
    required String host,
    required List<String> pathSegments,
    required String? dest,
    required String? sessionId,
  }) {
    if (host == 'open') {
      return _destinationFromName(dest, sessionId: sessionId);
    }

    if (host.isNotEmpty) {
      if (host == 'session') {
        final id = _firstNonEmpty(pathSegments) ?? sessionId;
        if (id != null && id.isNotEmpty) {
          return DeepLinkDestination.session(id);
        }
        return DeepLinkDestination.capture;
      }
      return _destinationFromName(host, sessionId: sessionId);
    }

    if (pathSegments.isEmpty) {
      return _destinationFromName(dest, sessionId: sessionId);
    }

    final first = pathSegments.first.toLowerCase();
    if (first == 'session') {
      final id = pathSegments.length > 1
          ? pathSegments[1]
          : sessionId;
      if (id != null && id.isNotEmpty) {
        return DeepLinkDestination.session(id);
      }
      return DeepLinkDestination.capture;
    }

    return _destinationFromName(first, sessionId: sessionId);
  }

  DeepLinkDestination _destinationFromName(
    String? name, {
    String? sessionId,
  }) {
    switch (name?.toLowerCase()) {
      case 'closet':
        return DeepLinkDestination.closet;
      case 'history':
        return DeepLinkDestination.history;
      case 'paywall':
        return DeepLinkDestination.paywall;
      case 'billing':
        return DeepLinkDestination.billing;
      case 'session':
        if (sessionId != null && sessionId.isNotEmpty) {
          return DeepLinkDestination.session(sessionId);
        }
        return DeepLinkDestination.capture;
      case 'capture':
      case null:
      case '':
        return DeepLinkDestination.capture;
      default:
        return DeepLinkDestination.capture;
    }
  }

  String? _firstNonEmpty(List<String> segments) {
    for (final segment in segments) {
      if (segment.isNotEmpty) return segment;
    }
    return null;
  }
}
