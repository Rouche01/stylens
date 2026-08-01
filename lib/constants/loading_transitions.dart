import 'package:flutter/animation.dart';

/// Shared motion tokens for skeleton ↔ content transitions.
abstract final class LoadingTransitions {
  static const Duration duration = Duration(milliseconds: 220);
  static const Curve switchInCurve = Curves.easeOut;
  static const Curve switchOutCurve = Curves.easeIn;
}
