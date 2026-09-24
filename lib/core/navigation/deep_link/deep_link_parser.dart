import 'package:gostylens/core/navigation/deep_link/deep_link_destination.dart';
import 'package:gostylens/core/navigation/deep_link/push_notification_types.dart';
import 'package:gostylens/core/managers/invite_code_manager.dart';

class DeepLinkParser {
  static const supportedScheme = 'gostylens';

  /// HTTPS hosts claimed by Universal Links (iOS) and App Links (Android).
  static const httpsHosts = {'gostylens.app', 'www.gostylens.app'};

  /// Custom-scheme `gostylens://…` or HTTPS `https://gostylens.app/…`.
  static bool isAppLink(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    if (scheme == supportedScheme) return true;
    return scheme == 'https' && httpsHosts.contains(uri.host.toLowerCase());
  }

  /// Returns null when [uri] is not a GoStylens deep link (e.g. Google OAuth).
  /// Invite-only links (`gostylens://invite?…` or `/invite`) return null so
  /// navigation falls through to the stage-neutral route after the code is
  /// persisted.
  DeepLinkDestination? parseUri(Uri uri) {
    if (!isAppLink(uri)) return null;

    final parts = _decompose(uri);

    if (_isInviteOnly(
      host: parts.host,
      pathSegments: parts.pathSegments,
      dest: uri.queryParameters['dest'],
    )) {
      return null;
    }

    return _parseLocation(
      host: parts.host,
      pathSegments: parts.pathSegments,
      dest: uri.queryParameters['dest'],
      sessionId: _normalizeSessionId(
        uri.queryParameters['session_id'] ?? uri.queryParameters['sessionId'],
      ),
    );
  }

  /// Extracts a normalized invite code from a GoStylens URI, if present.
  String? extractInviteCode(Uri uri) {
    if (!isAppLink(uri)) return null;

    final fromQuery = InviteCodeManager.normalize(
      uri.queryParameters['code'] ?? uri.queryParameters['inviteCode'],
    );
    if (fromQuery != null) return fromQuery;

    final parts = _decompose(uri);
    if (parts.host == 'invite' && parts.pathSegments.isNotEmpty) {
      return InviteCodeManager.normalize(parts.pathSegments.first);
    }

    return null;
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
    final sessionId = _normalizeSessionId(
      data['session_id'] ?? data['sessionId'],
    );

    if (type == PushNotificationTypes.styleAdviceReady && sessionId != null) {
      return DeepLinkDestination.session(sessionId);
    }

    if (type == PushNotificationTypes.dailyStyleNudge) {
      return DeepLinkDestination.capture;
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

  /// Maps custom-scheme hosts and HTTPS path prefixes onto the same
  /// `(host, pathSegments)` shape used by [_parseLocation].
  ///
  /// `gostylens://session/abc` and `https://gostylens.app/session/abc` both
  /// become `host=session`, `pathSegments=[abc]`.
  ({String host, List<String> pathSegments}) _decompose(Uri uri) {
    var host = '';
    var pathSegments = <String>[];

    if (uri.scheme.toLowerCase() == 'https') {
      pathSegments = uri.pathSegments
          .where((segment) => segment.isNotEmpty)
          .toList();
    } else {
      host = uri.host;
      pathSegments = List<String>.from(uri.pathSegments);
      // Some platforms emit gostylens:/history (path-only) instead of
      // gostylens://history.
      if (host.isEmpty && pathSegments.isEmpty && uri.path.isNotEmpty) {
        pathSegments = uri.path
            .split('/')
            .where((segment) => segment.isNotEmpty)
            .toList();
      }
    }

    if (host.isEmpty && pathSegments.isNotEmpty) {
      host = pathSegments.first;
      pathSegments = pathSegments.skip(1).toList();
    }

    return (host: host.toLowerCase(), pathSegments: pathSegments);
  }

  String? _normalizeSessionId(dynamic raw) {
    if (raw == null) return null;
    final id = raw.toString().trim();
    return id.isEmpty ? null : id;
  }

  bool _isInviteOnly({
    required String host,
    required List<String> pathSegments,
    required String? dest,
  }) {
    if (host == 'invite') return true;
    if (host == 'open' && dest?.toLowerCase() == 'invite') {
      return true;
    }
    if (host.isEmpty &&
        pathSegments.isNotEmpty &&
        pathSegments.first.toLowerCase() == 'invite') {
      return true;
    }
    return false;
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
      final id = pathSegments.length > 1 ? pathSegments[1] : sessionId;
      if (id != null && id.isNotEmpty) {
        return DeepLinkDestination.session(id);
      }
      return DeepLinkDestination.capture;
    }

    return _destinationFromName(first, sessionId: sessionId);
  }

  DeepLinkDestination _destinationFromName(String? name, {String? sessionId}) {
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
