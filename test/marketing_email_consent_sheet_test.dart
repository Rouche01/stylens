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
}
