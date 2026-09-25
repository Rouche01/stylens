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

      await tester.tap(find.byIcon(Icons.close));
      expect(dismissed, isTrue);
    });

    testWidgets('stacked CTA when action provided', (tester) async {
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
      await tester.tap(find.text('View'));
      expect(opened, isTrue);
    });

    test('marginFor clears floating dock height', () {
      final margin = InAppNotificationSnackBar.marginFor(null);
      expect(margin.left, InAppNotificationSnackBar.horizontalInset);
      expect(margin.right, InAppNotificationSnackBar.horizontalInset);
      expect(
        margin.bottom,
        FloatingNavBar.height +
            InAppNotificationSnackBar.dockGap +
            InAppNotificationSnackBar.horizontalInset,
      );
    });
  });
}
