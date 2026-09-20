import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:gostylens/models/closet_item.dart';

/// Cover-fit geometry for the item hero. Overlay math must use the same
/// [BoxFit] and [alignment] as the photo, or the box lands on the crop.
abstract final class ClosetItemHeroLayout {
  static const aspectRatio = 3 / 4;
  static const radius = 22.0;
  static const boxRadius = 14.0;
  static const boxStrokeWidth = 2.0;
  static const dimOpacity = 0.55;
  static const horizontalInset = 16.0;

  /// Same top-bias as outfit covers elsewhere (`Alignment(0, -0.45)`).
  static const imageAlignment = Alignment(0, -0.45);

  /// Where the full original sits in hero space after [BoxFit.cover].
  /// May extend past the widget; the photo clips, the box can too.
  static Rect coverFittedImageRect({
    required Size imageSize,
    required Size widgetSize,
    Alignment alignment = imageAlignment,
  }) {
    if (imageSize.isEmpty || widgetSize.isEmpty) return Rect.zero;
    final scale = math.max(
      widgetSize.width / imageSize.width,
      widgetSize.height / imageSize.height,
    );
    final fitted = Size(imageSize.width * scale, imageSize.height * scale);
    return alignment.inscribe(fitted, Offset.zero & widgetSize);
  }

  /// Percent box on the full original, mapped into hero widget space.
  static Rect? percentBoxOnCoverFit({
    required ClosetPercentBox box,
    required Size imageSize,
    required Size widgetSize,
    Alignment alignment = imageAlignment,
  }) {
    if (box.width <= 0 || box.height <= 0) return null;
    final imageRect = coverFittedImageRect(
      imageSize: imageSize,
      widgetSize: widgetSize,
      alignment: alignment,
    );
    if (imageRect.isEmpty) return null;
    return Rect.fromLTWH(
      imageRect.left + imageRect.width * box.x / 100,
      imageRect.top + imageRect.height * box.y / 100,
      imageRect.width * box.width / 100,
      imageRect.height * box.height / 100,
    );
  }
}
