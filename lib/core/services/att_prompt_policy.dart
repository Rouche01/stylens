import 'package:app_tracking_transparency/app_tracking_transparency.dart';

/// Why a tracking flush is running.
enum AttTrigger { initial, captureSettled, resume }

/// What an iOS flush should do before AppsFlyer may start.
enum AttAction { start, request, skip }

/// Asks at most once up front, once after Capture has settled, and once on resume.
class AttPromptMachine {
  static const attemptCap = 3;

  int attempts = 0;
  bool started = false;
  bool initialUsed = false;
  bool captureRetryUsed = false;
  bool resumeRetryUsed = false;

  bool shouldAttempt(AttTrigger trigger) {
    if (started || attempts >= attemptCap) return false;
    return switch (trigger) {
      AttTrigger.initial => !initialUsed,
      AttTrigger.captureSettled => !captureRetryUsed,
      AttTrigger.resume => !resumeRetryUsed,
    };
  }

  void record(AttTrigger trigger) {
    attempts++;
    switch (trigger) {
      case AttTrigger.initial:
        initialUsed = true;
      case AttTrigger.captureSettled:
        captureRetryUsed = true;
      case AttTrigger.resume:
        resumeRetryUsed = true;
    }
  }

  void markStarted() => started = true;

  bool get shouldScheduleCaptureRetry =>
      !started && !captureRetryUsed && attempts < attemptCap;

  bool get shouldObserveResume =>
      !started && !resumeRetryUsed && attempts < attemptCap;
}

/// Android starts with no dialog. iOS starts only after a real answer.
bool shouldStartAppsFlyer({
  required bool isIos,
  required TrackingStatus? status,
}) {
  if (!isIos) return true;
  if (status == null || status == TrackingStatus.notDetermined) return false;
  return true;
}

AttAction attAction({
  required bool isIos,
  required TrackingStatus? status,
  required bool alreadyStarted,
}) {
  if (alreadyStarted) return AttAction.skip;
  if (!isIos) return AttAction.start;
  if (!shouldStartAppsFlyer(isIos: true, status: status)) {
    return AttAction.request;
  }
  return AttAction.start;
}

/// Set from the router so tracking retries can see Capture without a cycle.
class AttCaptureVisibility {
  static bool Function() check = () => false;
}
