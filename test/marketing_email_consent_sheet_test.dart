import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostylens/constants/ux_messages.dart';
import 'package:gostylens/widgets/marketing_email_consent_sheet.dart';

void main() {
  testWidgets('Yes pops true and Not now pops false', (tester) async {
    bool? first;
    bool? second;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Column(
              children: [
                TextButton(
                  onPressed: () async {
                    first = await MarketingEmailConsentSheet.show(context);
                  },
                  child: const Text('open-yes'),
                ),
                TextButton(
                  onPressed: () async {
                    second = await MarketingEmailConsentSheet.show(context);
                  },
                  child: const Text('open-no'),
                ),
              ],
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open-yes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(UxMessages.marketingEmailYes));
    await tester.pumpAndSettle();
    expect(first, isTrue);

    await tester.tap(find.text('open-no'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(UxMessages.marketingEmailNotNow));
    await tester.pumpAndSettle();
    expect(second, isFalse);
  });

  testWidgets('dismisses keyboard before showing', (tester) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return Column(
                children: [
                  Focus(focusNode: focusNode, child: const SizedBox.shrink()),
                  TextButton(
                    onPressed: () => MarketingEmailConsentSheet.show(context),
                    child: const Text('open'),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );

    focusNode.requestFocus();
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);

    await tester.tap(find.text('open'));
    await tester.pump();
    expect(focusNode.hasFocus, isFalse);

    await tester.pumpAndSettle();
    expect(find.text(UxMessages.marketingEmailTitle), findsOneWidget);
  });

  testWidgets('waits for keyboard inset to clear before showing', (
    tester,
  ) async {
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () => MarketingEmailConsentSheet.show(context),
              child: const Text('open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pump();
    expect(find.text(UxMessages.marketingEmailTitle), findsNothing);

    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pumpAndSettle();
    expect(find.text(UxMessages.marketingEmailTitle), findsOneWidget);
  });
}
