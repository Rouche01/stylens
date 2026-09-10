import 'package:flutter/material.dart';
import 'package:gostylens/constants/ux_messages.dart';
import 'package:gostylens/widgets/custom_outlined_button.dart';
import 'package:gostylens/widgets/primary_button.dart';

/// Optional Yes / Not now sheet. Returns `true` for Yes, `false` for Not now.
class MarketingEmailConsentSheet extends StatelessWidget {
  const MarketingEmailConsentSheet({super.key});

  static Future<bool?> show(BuildContext context) async {
    await _dismissKeyboard(context);
    if (!context.mounted) return null;

    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.tertiary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const MarketingEmailConsentSheet(),
    );
  }

  static Future<void> _dismissKeyboard(BuildContext context) async {
    FocusManager.instance.primaryFocus?.unfocus();

    final view = View.of(context);
    if (view.viewInsets.bottom == 0) return;

    final deadline = DateTime.now().add(const Duration(milliseconds: 500));
    while (context.mounted &&
        view.viewInsets.bottom > 0 &&
        DateTime.now().isBefore(deadline)) {
      await WidgetsBinding.instance.endOfFrame;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 8, 24, 16 + keyboardInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              UxMessages.marketingEmailTitle,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w600,
                height: 1.2,
                letterSpacing: -0.3,
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
      ),
    );
  }
}
