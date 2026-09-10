import 'package:gostylens/core/config/dependency_injection.dart';
import 'package:gostylens/core/config/feature_flags.dart';
import 'package:gostylens/core/managers/user_state_manager.dart';
import 'package:gostylens/core/marketing_email/consent.dart';
import 'package:gostylens/core/prefs/local_prefs_service.dart';
import 'package:gostylens/core/prefs/pref_keys.dart';
import 'package:gostylens/core/navigation/app_navigation_keys.dart';
import 'package:gostylens/core/services/analytics_service.dart';
import 'package:gostylens/core/services/feature_flag_service.dart';
import 'package:gostylens/widgets/marketing_email_consent_sheet.dart';

/// One soft prompt after the first successful tip when the user never opted in.
class MarketingEmailReask {
  static Future<void> maybePromptAfterFirstTip() async {
    if (!locator.isRegistered<LocalPrefsService>() ||
        !locator.isRegistered<UserStateManager>() ||
        !locator.isRegistered<FeatureFlagService>()) {
      return;
    }

    final flagOn = await locator<FeatureFlagService>().isEnabled(
      FeatureFlags.marketingEmailNudgeOnFirstTip,
    );
    if (!flagOn) return;

    final prefs = locator<LocalPrefsService>();
    if (prefs.getOr(PrefKeys.marketingEmailReaskShown, false)) return;

    final userState = locator<UserStateManager>();
    if (userState.emailPrefs == null) {
      await userState.fetchEmailPrefs();
    }
    if (!MarketingEmailConsent.isSoftReaskEligible(userState.emailPrefs)) {
      return;
    }

    final context = rootNavigatorKey.currentContext;
    if (context == null || !context.mounted) return;

    await prefs.set(PrefKeys.marketingEmailReaskShown, true);

    if (!context.mounted) return;
    final accepted = await MarketingEmailConsentSheet.show(context);
    if (accepted == true) {
      final ok = await userState.setMarketingOptIn(true);
      if (ok) {
        locator<AnalyticsService>().capture(
          'marketing_email_opt_in',
          properties: {'source': MarketingEmailConsent.sourcePostFirstTip},
        );
      }
    } else {
      locator<AnalyticsService>().capture(
        'marketing_email_declined',
        properties: {'source': MarketingEmailConsent.sourcePostFirstTip},
      );
    }
  }
}
