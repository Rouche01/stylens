import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostylens/widgets/primary_button.dart';
import 'package:integration_test/integration_test.dart';
import 'package:gostylens/main.dart' as app;
import 'dart:io' show Platform;
import 'package:gostylens/widgets/style_analysis_session_card.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> captureScreen(IntegrationTestWidgetsFlutterBinding binding, String name) async {
  if (Platform.isAndroid) {
    print('STYLENS_TEST: CAPTURE_$name');
    await Future.delayed(const Duration(seconds: 4));
  } else {
    await binding.takeScreenshot(name);
  }
}

void main() {
  final IntegrationTestWidgetsFlutterBinding binding =
      IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Capture App Screenshots', (WidgetTester tester) async {
    // 1. Boot up the app
    app.main();

    // Wait for the app to settle
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(seconds: 1));
    }


    // Force sign out to ensure we hit the Auth Page
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      await Supabase.instance.client.auth.signOut();

      // Wait for the asynchronous sign-out to navigate the app to the Auth page
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
    } catch (_) {}

    // Check if we are on the Auth Page and perform real login
    final Finder authPage = find.byKey(const ValueKey('auth_page'));
    if (authPage.evaluate().isNotEmpty) {
      // Capture Auth Screen
      await captureScreen(binding, 'screenshot_auth');

      // 1. Enter email
      final Finder emailField = find.byType(TextFormField).first;
      await tester.enterText(emailField, 'app-tester@gostylens.com');
      await tester.pump(const Duration(seconds: 1));

      // 2. Tap Continue
      final Finder continueButton = find.byType(PrimaryButton);
      await tester.tap(continueButton);
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(seconds: 1));
      }

      // 3. Enter OTP code 123456
      final Finder pinField = find.byType(EditableText).last;
      await tester.enterText(pinField, '123456');
      for (int i = 0; i < 8; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
    }

    // Wait for UI to load and images to fetch
    for (int i = 0; i < 3; i++) {
      await tester.pump(const Duration(seconds: 1));
    }

    // 2. Capture Home (Capture Page)
    await captureScreen(binding, 'screenshot_home');

    // Capture Gallery Picker
    final Finder chooseFromGalleryBtn = find.text('Choose from gallery');
    if (chooseFromGalleryBtn.evaluate().isNotEmpty) {
      await tester.tap(chooseFromGalleryBtn);
      await tester.pump(const Duration(seconds: 1));
      await captureScreen(binding, 'screenshot_choose_gallery');
    }

    // 3. Navigate to Closet Page
    final Finder closetTab = find.byIcon(Icons.checkroom_outlined);
    if (closetTab.evaluate().isNotEmpty) {
      await tester.tap(closetTab);
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      await captureScreen(binding, 'screenshot_closet');
    }

    // 4. Navigate to History Page
    final Finder historyTab = find.byIcon(Icons.history_outlined);
    if (historyTab.evaluate().isNotEmpty) {
      await tester.tap(historyTab);
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      await captureScreen(binding, 'screenshot_history');

      // Open a session to capture the chat screen
      final Finder sessionCard = find.byType(SessionCard).first;
      if (sessionCard.evaluate().isNotEmpty) {
        await tester.ensureVisible(sessionCard);
        for (int i = 0; i < 2; i++) {
          await tester.pump(const Duration(seconds: 1));
        }
        await tester.tap(sessionCard);
        // Avoid pumpAndSettle entirely to prevent Hero animation crashes
        for (int i = 0; i < 4; i++) {
          await tester.pump(const Duration(seconds: 1));
        }
        await captureScreen(binding, 'screenshot_style_analysis_chat');

        // Go back to History Page
        final Finder backButton = find.byIcon(Icons.arrow_back);
        if (backButton.evaluate().isNotEmpty) {
          await tester.tap(backButton.first);
          for (int i = 0; i < 3; i++) {
            await tester.pump(const Duration(seconds: 1));
          }
        }
      }
    }

    // 5. Navigate back to Capture Page to access Profile
    final Finder captureTab = find.byIcon(Icons.camera_alt_outlined);
    if (captureTab.evaluate().isNotEmpty) {
      await tester.tap(captureTab);
      for (int i = 0; i < 2; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
    }

    // 6. Navigate to Profile Page
    final Finder profileButton = find.byIcon(Icons.account_circle_rounded);
    if (profileButton.evaluate().isNotEmpty) {
      await tester.tap(profileButton);
      for (int i = 0; i < 3; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      await captureScreen(binding, 'screenshot_profile');
    }
  });
}
