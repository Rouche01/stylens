import 'package:flutter/material.dart';
import 'package:gostylens/constants/ux_messages.dart';
import 'package:gostylens/widgets/custom_outlined_button.dart';
import 'package:gostylens/widgets/primary_button.dart';

/// Optional Yes / Not now sheet. Returns `true` for Yes, `false` for Not now.
class MarketingEmailConsentSheet extends StatelessWidget {
  const MarketingEmailConsentSheet({super.key});

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Theme.of(context).colorScheme.tertiary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const MarketingEmailConsentSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            UxMessages.marketingEmailTitle,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: cs.primary,
              fontFamily: 'ClashDisplay',
            ),
          ),
          const SizedBox(height: 12),
          Text(
            UxMessages.marketingEmailBody,
            style: TextStyle(
              fontSize: 15,
              height: 1.45,
              color: cs.primary.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: UxMessages.marketingEmailYes,
            onPressed: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: 12),
          CustomOutlinedButton(
            label: UxMessages.marketingEmailNotNow,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }
}
