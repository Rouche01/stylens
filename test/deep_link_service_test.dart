import 'package:flutter_test/flutter_test.dart';
import 'package:gostylens/core/navigation/deep_link/deep_link_destination.dart';
import 'package:gostylens/core/navigation/deep_link/deep_link_service.dart';
import 'package:gostylens/navigation/app_routes.dart';

void main() {
  group('DeepLinkService pending API', () {
    late DeepLinkService service;

    setUp(() {
      service = DeepLinkService();
    });

    test('stashPendingDestination and takePendingDestination round-trip', () {
      service.stashPendingDestination(DeepLinkDestination.billing);

      expect(service.hasPending, isTrue);
      final pending = service.takePendingDestination();
      expect(pending, isNotNull);
      expect(pending!.destination.target, DeepLinkTarget.billing);
      expect(pending.shellLocation, AppRoutes.capture);
      expect(service.hasPending, isFalse);
      expect(service.takePendingDestination(), isNull);
    });

    test('session pending uses History as semantic shell', () {
      service.stashPendingDestination(DeepLinkDestination.session('s1'));

      final pending = service.takePendingDestination();
      expect(pending?.destination.target, DeepLinkTarget.session);
      expect(pending?.destination.sessionId, 's1');
      expect(pending?.shellLocation, AppRoutes.history);
    });

    test('takePendingDestination clears pending so it is only honored once', () {
      service.stashPendingDestination(DeepLinkDestination.history);

      expect(
        service.takePendingDestination()?.destination,
        DeepLinkDestination.history,
      );
      expect(service.takePendingDestination(), isNull);
    });

    test('setNavigationReady does not imperatively dispatch pending', () {
      service.stashPendingDestination(DeepLinkDestination.paywall);
      service.setNavigationReady(true);

      expect(service.hasPending, isTrue);
      final pending = service.takePendingDestination();
      expect(pending?.destination.target, DeepLinkTarget.paywall);
      expect(pending?.shellLocation, AppRoutes.capture);
    });
  });
}
