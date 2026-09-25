import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostylens/core/managers/foreground_notification_handler.dart';
import 'package:gostylens/core/navigation/app_navigation_keys.dart';
import 'package:gostylens/core/navigation/deep_link/deep_link_destination.dart';
import 'package:gostylens/core/navigation/deep_link/deep_link_parser.dart';
import 'package:gostylens/core/navigation/deep_link/push_notification_types.dart';
import 'package:gostylens/widgets/in_app_notification_snackbar.dart';

RemoteMessage _message({
  required Map<String, dynamic> data,
  String? title,
  String? body,
}) {
  return RemoteMessage(
    data: data.map((key, value) => MapEntry(key, value?.toString() ?? '')),
    notification: (title != null || body != null)
        ? RemoteNotification(title: title, body: body)
        : null,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DeepLinkParser parser;
  late List<DeepLinkDestination> viewingChecks;
  late List<Map<String, dynamic>> opened;
  late bool Function(DeepLinkDestination) viewingDestination;

  setUp(() {
    parser = DeepLinkParser();
    viewingChecks = [];
    opened = [];
    viewingDestination = (destination) {
      viewingChecks.add(destination);
      return false;
    };
  });

  Future<void> pumpHost(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: rootNavigatorKey,
        scaffoldMessengerKey: rootScaffoldMessengerKey,
        home: const Scaffold(body: SizedBox.expand()),
      ),
    );
  }

  ForegroundNotificationHandler buildHandler({
    bool Function(DeepLinkDestination)? viewing,
  }) {
    return ForegroundNotificationHandler(
      parser: parser,
      viewingDestination: viewing ?? viewingDestination,
      openPush: opened.add,
    );
  }

  group('ForegroundNotificationHandler suppress', () {
    testWidgets('skips empty title and body', (tester) async {
      await pumpHost(tester);
      buildHandler().handle(_message(data: {'type': 'daily_style_nudge'}));
      await tester.pump();

      expect(find.byType(InAppNotificationSnackBar), findsNothing);
      expect(viewingChecks, isEmpty);
    });

    testWidgets('suppresses when already viewing destination', (tester) async {
      await pumpHost(tester);
      buildHandler(viewing: (_) => true).handle(
        _message(
          data: {
            'type': PushNotificationTypes.dailyStyleNudge,
            'link': 'gostylens://capture',
          },
          title: 'GoStylens',
          body: "Got an outfit on? Let's take a look.",
        ),
      );
      await tester.pump();

      expect(find.byType(InAppNotificationSnackBar), findsNothing);
    });

    testWidgets('suppresses Capture destination while on Capture', (
      tester,
    ) async {
      await pumpHost(tester);
      DeepLinkDestination? seen;
      buildHandler(
        viewing: (destination) {
          seen = destination;
          return destination.target == DeepLinkTarget.capture;
        },
      ).handle(
        _message(
          data: {
            'type': PushNotificationTypes.dailyStyleNudge,
            'link': 'gostylens://capture',
          },
          body: 'Nudge body',
        ),
      );
      await tester.pump();

      expect(seen?.target, DeepLinkTarget.capture);
      expect(find.byType(InAppNotificationSnackBar), findsNothing);
    });

    testWidgets('suppresses session while viewing that session', (
      tester,
    ) async {
      await pumpHost(tester);
      buildHandler(
        viewing: (destination) =>
            destination.target == DeepLinkTarget.session &&
            destination.sessionId == 's1',
      ).handle(
        _message(
          data: {
            'type': PushNotificationTypes.styleAdviceReady,
            'session_id': 's1',
          },
          body: 'Your style advice is ready.',
        ),
      );
      await tester.pump();

      expect(find.byType(InAppNotificationSnackBar), findsNothing);
    });
  });

  group('ForegroundNotificationHandler chrome', () {
    testWidgets('daily nudge shows body, dismiss, Capture CTA — no title', (
      tester,
    ) async {
      await pumpHost(tester);
      buildHandler().handle(
        _message(
          data: {
            'type': PushNotificationTypes.dailyStyleNudge,
            'link': 'gostylens://capture',
          },
          title: 'GoStylens',
          body: "Got an outfit on? Let's take a look.",
        ),
      );
      await tester.pump();

      expect(find.byType(InAppNotificationSnackBar), findsOneWidget);
      expect(find.text("Got an outfit on? Let's take a look."), findsOneWidget);
      expect(find.text('GoStylens'), findsNothing);
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.text('Capture'), findsOneWidget);
      expect(find.text('Open'), findsNothing);
    });

    testWidgets('style advice shows View CTA when not on that session', (
      tester,
    ) async {
      await pumpHost(tester);
      buildHandler().handle(
        _message(
          data: {
            'type': PushNotificationTypes.styleAdviceReady,
            'session_id': 's2',
          },
          title: 'GoStylens',
          body: 'Your style advice is ready.',
        ),
      );
      await tester.pump();

      expect(find.text('Your style advice is ready.'), findsOneWidget);
      expect(find.text('GoStylens'), findsNothing);
      expect(find.text('View'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('Capture without link shows body + dismiss, no CTA', (
      tester,
    ) async {
      await pumpHost(tester);
      // No link + capture destination → canOpenFromPushData is false.
      buildHandler().handle(
        _message(
          data: {'type': PushNotificationTypes.dailyStyleNudge},
          body: 'Soft prompt only.',
        ),
      );
      await tester.pump();

      expect(find.text('Soft prompt only.'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.text('Capture'), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('dismiss closes snackbar without opening', (tester) async {
      await pumpHost(tester);
      buildHandler().handle(
        _message(
          data: {
            'type': PushNotificationTypes.dailyStyleNudge,
            'link': 'gostylens://capture',
          },
          body: 'Dismiss me',
        ),
      );
      await tester.pump();

      final snack = tester.widget<InAppNotificationSnackBar>(
        find.byType(InAppNotificationSnackBar),
      );
      snack.onDismiss();
      await tester.pumpAndSettle();

      expect(find.byType(InAppNotificationSnackBar), findsNothing);
      expect(opened, isEmpty);
    });

    testWidgets('Capture CTA opens deep link and closes snackbar', (
      tester,
    ) async {
      await pumpHost(tester);
      buildHandler().handle(
        _message(
          data: {
            'type': PushNotificationTypes.dailyStyleNudge,
            'link': 'gostylens://capture',
          },
          body: 'Open Capture',
        ),
      );
      await tester.pump();

      final snack = tester.widget<InAppNotificationSnackBar>(
        find.byType(InAppNotificationSnackBar),
      );
      expect(snack.actionLabel, 'Capture');
      snack.onAction!();
      await tester.pumpAndSettle();

      expect(opened, hasLength(1));
      expect(opened.single['link'], 'gostylens://capture');
      expect(find.byType(InAppNotificationSnackBar), findsNothing);
    });

    testWidgets('falls back to title when body is missing', (tester) async {
      await pumpHost(tester);
      buildHandler().handle(
        _message(
          data: {
            'type': PushNotificationTypes.styleAdviceReady,
            'session_id': 's9',
          },
          title: 'Advice ready',
        ),
      );
      await tester.pump();

      expect(find.text('Advice ready'), findsOneWidget);
      expect(find.text('View'), findsOneWidget);
    });
  });
}
