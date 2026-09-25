import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostylens/core/navigation/deep_link/deep_link_destination.dart';
import 'package:gostylens/widgets/floating_nav_bar.dart';
import 'package:gostylens/widgets/in_app_notification_snackbar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('actionLabelForDestination', () {
    test('maps targets to short pill labels', () {
      expect(actionLabelForDestination(DeepLinkDestination.capture), 'Capture');
      expect(actionLabelForDestination(DeepLinkDestination.closet), 'Closet');
      expect(actionLabelForDestination(DeepLinkDestination.history), 'History');
      expect(
        actionLabelForDestination(DeepLinkDestination.session('s1')),
        'View',
      );
      expect(actionLabelForDestination(DeepLinkDestination.paywall), 'View');
      expect(actionLabelForDestination(DeepLinkDestination.billing), 'View');
    });
  });

  group('InAppNotificationSnackBar', () {
    testWidgets('shows body and dismiss, no title row', (tester) async {
      var dismissed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InAppNotificationSnackBar(
              body: "Got an outfit on? Let's take a look.",
              onDismiss: () => dismissed = true,
            ),
          ),
        ),
      );

      expect(find.text("Got an outfit on? Let's take a look."), findsOneWidget);
      expect(find.text('GoStylens'), findsNothing);
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(TextButton), findsNothing);


      await tester.tap(find.byIcon(Icons.close));
      expect(dismissed, isTrue);
    });

    testWidgets('inline CTA when action provided', (tester) async {
      var opened = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InAppNotificationSnackBar(
              body: 'Your style advice is ready.',
              actionLabel: 'View',
              onAction: () => opened = true,
              onDismiss: () {},
            ),
          ),
        ),
      );

      expect(find.text('View'), findsOneWidget);
      expect(find.byType(TextButton), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
      // Body and CTA share one row (not a stacked column of two main blocks).
      final row = tester.widget<Row>(
        find.descendant(
          of: find.byType(InAppNotificationSnackBar),
          matching: find.byType(Row),
        ),
      );
      expect(row.children.length, greaterThanOrEqualTo(3));
      await tester.tap(find.text('View'));
      expect(opened, isTrue);
    });

    test(
      'marginFor clears floating dock without double-counting safe area',
      () {
        final fallback = InAppNotificationSnackBar.marginFor(null);
        expect(fallback.left, InAppNotificationSnackBar.horizontalInset);
        expect(fallback.right, InAppNotificationSnackBar.horizontalInset);
        expect(
          fallback.bottom,
          FloatingNavBar.height + InAppNotificationSnackBar.dockGap,
        );
      },
    );

    testWidgets('marginFor subtracts viewPadding already applied by Scaffold', (
      tester,
    ) async {
      late EdgeInsets margin;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            viewPadding: EdgeInsets.only(bottom: 34),
            padding: EdgeInsets.only(bottom: 34),
          ),
          child: Builder(
            builder: (context) {
              margin = InAppNotificationSnackBar.marginFor(context);
              return const SizedBox();
            },
          ),
        ),
      );

      // dockTop = (34 - 6) + 64 = 92; margin = 92 + 4 - 34 = 62
      expect(margin.bottom, 62);
    });

    test('marginFor skips dock clearance off the tab shell', () {
      final margin = InAppNotificationSnackBar.marginFor(
        null,
        clearFloatingDock: false,
      );
      expect(margin.bottom, 12);
      expect(margin.bottom, lessThan(FloatingNavBar.height));
    });
  });
}
