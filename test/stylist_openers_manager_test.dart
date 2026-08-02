import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gostylens/constants/ux_messages.dart';
import 'package:gostylens/core/managers/stylist_openers_manager.dart';
import 'package:gostylens/models/api_responses/stylist_openers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  StylistOpenersManager managerWithPool(
    List<StylistOpenerMessage> messages, {
    List<String>? recentIds,
    int seed = 1,
  }) {
    final manager = StylistOpenersManager(random: Random(seed));
    manager.debugSetPool(
      StylistOpenersPool(version: 1, messages: messages),
      recentIds: recentIds,
    );
    return manager;
  }

  group('StylistOpenersManager.pickTexts', () {
    test('falls back to UxMessages when pool is empty', () {
      final manager = StylistOpenersManager(random: Random(1));
      manager.debugSetPool(const StylistOpenersPool(version: 0, messages: []));

      expect(
        manager.pickOne(StylistOpenerTag.withImage),
        UxMessages.initialStylistReplyWithImage,
      );
      expect(
        manager.pickOne(StylistOpenerTag.withoutImage),
        UxMessages.initialStylistReplyWithoutImage1,
      );
    });

    test('picks by tag from pool', () {
      final manager = managerWithPool([
        const StylistOpenerMessage(
          id: 'w1',
          text: 'With A',
          tags: [StylistOpenerTag.withImage],
        ),
        const StylistOpenerMessage(
          id: 'n1',
          text: 'Without A',
          tags: [StylistOpenerTag.withoutImage],
        ),
        const StylistOpenerMessage(
          id: 'n2',
          text: 'Without B',
          tags: [StylistOpenerTag.withoutImage],
        ),
      ]);

      expect(manager.pickOne(StylistOpenerTag.withImage), 'With A');
      expect(
        manager.pickOne(StylistOpenerTag.withoutImage),
        anyOf('Without A', 'Without B'),
      );
    });

    test('avoids recently used ids when alternatives exist', () {
      final manager = managerWithPool(
        [
          const StylistOpenerMessage(
            id: 'a',
            text: 'Alpha',
            tags: [StylistOpenerTag.withImage],
          ),
          const StylistOpenerMessage(
            id: 'b',
            text: 'Bravo',
            tags: [StylistOpenerTag.withImage],
          ),
        ],
        recentIds: ['a'],
        seed: 42,
      );

      expect(manager.pickOne(StylistOpenerTag.withImage), 'Bravo');
    });

    test('reuses when all candidates were recent', () {
      final manager = managerWithPool(
        [
          const StylistOpenerMessage(
            id: 'only',
            text: 'Only one',
            tags: [StylistOpenerTag.withImage],
          ),
        ],
        recentIds: ['only'],
      );

      expect(manager.pickOne(StylistOpenerTag.withImage), 'Only one');
    });
  });
}
