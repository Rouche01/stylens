import 'package:gostylens/core/navigation/deep_link/deep_link_destination.dart';

/// A deep-link destination waiting to be consumed, with the tab shell that
/// should sit beneath it when pushed.
class PendingDeepLink {
  const PendingDeepLink({
    required this.destination,
    required this.shellLocation,
  });

  final DeepLinkDestination destination;
  final String shellLocation;
}
