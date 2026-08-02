import 'package:flutter_test/flutter_test.dart';
import 'package:gostylens/models/api_responses/stylist_openers.dart';

void main() {
  group('StylistOpenersPool', () {
    test('fromJson parses version, messages, and tags', () {
      final pool = StylistOpenersPool.fromJson({
        'version': 3,
        'messages': [
          {
            'id': '1',
            'text': 'Hello',
            'tags': ['with_image', 'bogus', 'with_image'],
          },
          {
            'id': '2',
            'text': 'Hi',
            'tags': ['without_image'],
          },
        ],
      });

      expect(pool.version, 3);
      expect(pool.messages, hasLength(2));
      expect(pool.messages[0].tags, [StylistOpenerTag.withImage]);
      expect(pool.messages[1].hasTag(StylistOpenerTag.withoutImage), isTrue);
    });
  });
}
