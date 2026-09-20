import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostylens/models/closet_item.dart';
import 'package:gostylens/pages/closet/closet_item_hero_layout.dart';

void main() {
  group('ClosetItemHeroLayout.percentBoxOnCoverFit', () {
    test('maps a percent box onto a cover-fitted square in a tall frame', () {
      const box = ClosetPercentBox(x: 25, y: 25, width: 50, height: 50);
      final rect = ClosetItemHeroLayout.percentBoxOnCoverFit(
        box: box,
        imageSize: const Size(100, 100),
        widgetSize: const Size(100, 200),
        alignment: Alignment.center,
      );

      expect(rect, const Rect.fromLTWH(0, 50, 100, 100));
    });

    test('uses hero alignment so the box tracks the cropped original', () {
      const box = ClosetPercentBox(x: 0, y: 0, width: 100, height: 100);
      final rect = ClosetItemHeroLayout.percentBoxOnCoverFit(
        box: box,
        imageSize: const Size(100, 200),
        widgetSize: const Size(100, 100),
      );

      final imageRect = ClosetItemHeroLayout.coverFittedImageRect(
        imageSize: const Size(100, 200),
        widgetSize: const Size(100, 100),
      );
      expect(rect, imageRect);
      expect(rect!.top, lessThan(0));
    });

    test('returns null when the box has no area', () {
      expect(
        ClosetItemHeroLayout.percentBoxOnCoverFit(
          box: const ClosetPercentBox(x: 10, y: 10, width: 0, height: 40),
          imageSize: const Size(100, 100),
          widgetSize: const Size(100, 200),
        ),
        isNull,
      );
    });
  });
}
