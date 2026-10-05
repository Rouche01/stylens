import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostylens/core/services/att_prompt_policy.dart';

void main() {
  test('notDetermined does not start and allows a Capture retry', () {
    final machine = AttPromptMachine();

    expect(
      attAction(
        isIos: true,
        status: TrackingStatus.notDetermined,
        alreadyStarted: false,
      ),
      AttAction.request,
    );
    expect(
      shouldStartAppsFlyer(
        isIos: true,
        status: TrackingStatus.notDetermined,
      ),
      isFalse,
    );

    machine.record(AttTrigger.initial);
    expect(machine.shouldScheduleCaptureRetry, isTrue);
    expect(machine.shouldAttempt(AttTrigger.captureSettled), isTrue);
  });

  test('denied or authorized starts once', () {
    for (final status in [TrackingStatus.denied, TrackingStatus.authorized]) {
      final machine = AttPromptMachine();
      expect(
        shouldStartAppsFlyer(isIos: true, status: status),
        isTrue,
      );
      expect(
        attAction(isIos: true, status: status, alreadyStarted: false),
        AttAction.start,
      );
      machine.record(AttTrigger.initial);
      machine.markStarted();
      expect(machine.shouldAttempt(AttTrigger.initial), isFalse);
      expect(machine.shouldAttempt(AttTrigger.captureSettled), isFalse);
      expect(machine.shouldAttempt(AttTrigger.resume), isFalse);
      expect(
        attAction(isIos: true, status: status, alreadyStarted: true),
        AttAction.skip,
      );
    }
  });

  test('android starts with no tracking request', () {
    expect(
      attAction(isIos: false, status: null, alreadyStarted: false),
      AttAction.start,
    );
    expect(shouldStartAppsFlyer(isIos: false, status: null), isTrue);
  });

  test('stops after the initial, Capture, and resume attempts', () {
    final machine = AttPromptMachine();
    machine.record(AttTrigger.initial);
    machine.record(AttTrigger.captureSettled);
    machine.record(AttTrigger.resume);

    expect(machine.shouldAttempt(AttTrigger.resume), isFalse);
    expect(machine.shouldScheduleCaptureRetry, isFalse);
    expect(machine.shouldObserveResume, isFalse);
  });
}
