import 'package:flutter_test/flutter_test.dart';
import 'package:gostylens/core/managers/intro_walkthrough_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('IntroWalkthroughStore', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('warm defaults to not completed', () async {
      final store = IntroWalkthroughStore();
      await store.warm();
      expect(store.hasCompleted, isFalse);
    });

    test('markCompleted persists across warm', () async {
      final store = IntroWalkthroughStore();
      await store.warm();
      await store.markCompleted();
      expect(store.hasCompleted, isTrue);

      final again = IntroWalkthroughStore();
      await again.warm();
      expect(again.hasCompleted, isTrue);
    });

    test('hasCompleted is false before warm', () {
      final store = IntroWalkthroughStore();
      expect(store.hasCompleted, isFalse);
    });
  });
}
