import 'package:flutter_test/flutter_test.dart';
import 'package:gostylens/models/closet_identity_status.dart';

void main() {
  group('ClosetIdentityStatus.fromJson', () {
    test('parses GET /closet/identity/status without phase', () {
      final status = ClosetIdentityStatus.fromJson({
        'processing': true,
        'queued': 2,
        'running': 1,
        'failed': 0,
      });

      expect(status.processing, isTrue);
      expect(status.queued, 2);
      expect(status.running, 1);
      expect(status.failed, 0);
      expect(status.phase, isNull);
    });

    test('parses closet_identity_updated started and settled', () {
      final started = ClosetIdentityStatus.fromJson({
        'processing': true,
        'queued': 1,
        'running': 0,
        'failed': 0,
        'phase': 'started',
      });
      final settled = ClosetIdentityStatus.fromJson({
        'processing': false,
        'queued': 0,
        'running': 0,
        'failed': 0,
        'phase': 'settled',
      });

      expect(started.phase, ClosetIdentityPhase.started);
      expect(started.processing, isTrue);
      expect(settled.phase, ClosetIdentityPhase.settled);
      expect(settled.processing, isFalse);
    });

    test('keeps failed counts without treating them as processing', () {
      final status = ClosetIdentityStatus.fromJson({
        'processing': false,
        'queued': 0,
        'running': 0,
        'failed': 3,
      });

      expect(status.processing, isFalse);
      expect(status.failed, 3);
    });

    test('defaults missing fields and ignores unknown phase', () {
      final status = ClosetIdentityStatus.fromJson({'phase': 'running'});

      expect(status.processing, isFalse);
      expect(status.queued, 0);
      expect(status.running, 0);
      expect(status.failed, 0);
      expect(status.phase, isNull);
    });

    test('coerces numeric strings and drops negative counts', () {
      final status = ClosetIdentityStatus.fromJson({
        'processing': true,
        'queued': '2',
        'running': 1.9,
        'failed': -4,
      });

      expect(status.queued, 2);
      expect(status.running, 1);
      expect(status.failed, 0);
    });
  });

  group('ClosetIdentityStatus.fromResponse', () {
    test('reads a map payload', () {
      final status = ClosetIdentityStatus.fromResponse({
        'processing': true,
        'queued': 0,
        'running': 1,
        'failed': 0,
        'phase': 'started',
      });

      expect(status.processing, isTrue);
      expect(status.running, 1);
      expect(status.phase, ClosetIdentityPhase.started);
    });

    test('returns idle when the payload is not a map', () {
      expect(ClosetIdentityStatus.fromResponse(null).processing, isFalse);
      expect(ClosetIdentityStatus.fromResponse('busy').queued, 0);
      expect(ClosetIdentityStatus.fromResponse([]).failed, 0);
    });
  });
}
