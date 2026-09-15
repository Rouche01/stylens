import 'package:flutter_test/flutter_test.dart';
import 'package:gostylens/models/closet_item.dart';

void main() {
  group('ClosetItem.fromJson', () {
    test('parses list fields and maps API categories', () {
      final item = ClosetItem.fromJson({
        'id': 'c1',
        'label': 'Ivory knit',
        'category': 'top',
        'subcategory': 'sweater',
        'color': 'ivory',
        'isolated_image_url':
            'https://api.example.com/assets/isolate?key=p.jpg&width=480',
        'original_image_url': 'https://r2.example/photo.jpg',
        'image_key': 'users/u1/photo.jpg',
        'tile_aspect_ratio': 0.72,
        'blur_hash': 'LEHV6nWB2yk8pyo0adR*.7kCMdnj',
      });

      expect(item.id, 'c1');
      expect(item.displayName, 'Ivory knit');
      expect(item.displayCategory, 'Tops');
      expect(item.tileImageUrl, contains('width=480'));
      expect(item.imageKey, 'users/u1/photo.jpg');
      expect(item.aspectRatio, 0.72);
      expect(item.blurHash, 'LEHV6nWB2yk8pyo0adR*.7kCMdnj');
    });

    test('falls back to 4/5 and Other when size or category is missing', () {
      final item = ClosetItem.fromJson({
        'id': 'c2',
        'label': 'Scarf',
        'category': 'unknown',
      });

      expect(item.displayCategory, 'Other');
      expect(item.aspectRatio, ClosetItem.fallbackAspectRatio);
      expect(item.tileImageUrl, isNull);
      expect(item.blurHash, isNull);
    });

    test('maps remaining extraction slugs', () {
      expect(
        ClosetItem.fromJson({'category': 'bottom'}).displayCategory,
        'Bottoms',
      );
      expect(
        ClosetItem.fromJson({'category': 'outerwear'}).displayCategory,
        'Outerwear',
      );
      expect(
        ClosetItem.fromJson({'category': 'footwear'}).displayCategory,
        'Shoes',
      );
      expect(
        ClosetItem.fromJson({'category': 'full-body'}).displayCategory,
        'Dresses',
      );
      expect(
        ClosetItem.fromJson({'category': 'accessory'}).displayCategory,
        'Accessories',
      );
    });
  });

  group('ClosetItem.listFromResponse', () {
    test('reads items from the list payload', () {
      final items = ClosetItem.listFromResponse({
        'items': [
          {'id': 'a', 'label': 'Tee', 'category': 'top'},
          {'id': 'b', 'label': 'Jeans', 'category': 'bottom'},
        ],
      });

      expect(items, hasLength(2));
      expect(items.map((item) => item.id), ['a', 'b']);
    });

    test('returns empty when the payload has no items', () {
      expect(ClosetItem.listFromResponse(null), isEmpty);
      expect(ClosetItem.listFromResponse({}), isEmpty);
    });
  });
}
