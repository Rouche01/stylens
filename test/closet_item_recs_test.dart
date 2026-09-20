import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostylens/pages/closet/closet_item_recs.dart';

void main() {
  group('ClosetItemRecs.bodyFor', () {
    test('swaps the locked jacket slot for the display name', () {
      expect(
        ClosetItemRecs.bodyFor('Leather Jacket'),
        'Tap a photo if it’s this Leather Jacket. We’ll use it for a cleaner '
        'presentation, or to try it on your twin.',
      );
    });

    test('falls back to piece when the name is empty', () {
      expect(ClosetItemRecs.bodyFor('  '), contains('this piece'));
    });
  });

  testWidgets('empty recs hide the grid and none of these', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ClosetItemRecs(displayName: 'Leather Jacket')),
      ),
    );

    expect(find.text(ClosetItemRecs.heading), findsOneWidget);
    expect(find.text(ClosetItemRecs.bodyFor('Leather Jacket')), findsOneWidget);
    expect(find.text('None of these'), findsNothing);
    expect(find.byKey(const ValueKey('closet-item-recs-grid')), findsNothing);
  });

  testWidgets('selecting a rec outlines it and none of these clears', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ClosetItemRecs(
            displayName: 'Leather Jacket',
            recs: [
              ClosetItemRec(
                id: 'a',
                title: 'Black leather',
                imageUrl: 'https://example/a.jpg',
              ),
              ClosetItemRec(
                id: 'b',
                title: 'Moto',
                imageUrl: 'https://example/b.jpg',
              ),
            ],
          ),
        ),
      ),
    );

    BoxBorder? borderOf(String id) {
      final box = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byKey(ValueKey('closet-item-rec-$id')),
          matching: find.byType(DecoratedBox),
        ),
      );
      return box.decoration is BoxDecoration
          ? (box.decoration as BoxDecoration).border
          : null;
    }

    expect(find.text('None of these'), findsOneWidget);
    await tester.tap(find.text('Moto'));
    await tester.pump();

    expect((borderOf('b') as Border?)?.top.color, isNot(Colors.transparent));
    expect((borderOf('a') as Border?)?.top.color, Colors.transparent);

    await tester.tap(find.text('None of these'));
    await tester.pump();
    expect((borderOf('b') as Border?)?.top.color, Colors.transparent);
  });
}
