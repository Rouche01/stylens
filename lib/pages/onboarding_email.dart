import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:gostylens/constants/ux_messages.dart';
import 'package:gostylens/core/config/dependency_injection.dart';
import 'package:gostylens/core/managers/user_state_manager.dart';
import 'package:gostylens/core/marketing_email/consent.dart';
import 'package:gostylens/core/services/analytics_service.dart';
import 'package:gostylens/models/api_responses/gender.dart';
import 'package:gostylens/widgets/custom_outlined_button.dart';
import 'package:gostylens/widgets/primary_button.dart';
import 'package:gostylens/widgets/step_progress_bar.dart';
import 'package:provider/provider.dart';

class OnboardingEmailPage extends StatelessWidget {
  const OnboardingEmailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final skipped = GoRouterState.of(context).extra == true;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surfaceDim,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            IconButton(
                              icon: FaIcon(
                                FontAwesomeIcons.arrowLeftLong,
                                color: cs.primary,
                              ),
                              onPressed: () => Navigator.of(context).maybePop(),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: StepProgressBar(
                                totalSteps: 3,
                                currentStep: 3,
                                activeColor: cs.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        Text(
                          UxMessages.marketingEmailTitle,
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w600,
                            color: cs.primary,
                            fontFamily: 'ClashDisplay',
                            height: 1.2,
                            letterSpacing: -0.6,
                          ),
                          textAlign: TextAlign.left,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          UxMessages.marketingEmailBody,
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.45,
                            fontWeight: FontWeight.w400,
                            color: cs.onSurface.withAlpha(180),
                          ),
                          textAlign: TextAlign.left,
                        ),
                        const Spacer(),
                        Consumer<UserStateManager>(
                          builder: (context, userStateManager, _) {
                            final busy =
                                userStateManager.operationState.isCreating;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                PrimaryButton(
                                  label: UxMessages.marketingEmailYes,
                                  onPressed: busy
                                      ? null
                                      : () => _complete(
                                          context,
                                          userStateManager,
                                          accepted: true,
                                          skipped: skipped,
                                        ),
                                  disabled: busy,
                                  isLoading: busy,
                                ),
                                const SizedBox(height: 12),
                                CustomOutlinedButton(
                                  label: UxMessages.marketingEmailNotNow,
                                  onPressed: busy
                                      ? null
                                      : () => _complete(
                                          context,
                                          userStateManager,
                                          accepted: false,
                                          skipped: skipped,
                                        ),
                                  disabled: busy,
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _complete(
    BuildContext context,
    UserStateManager userStateManager, {
    required bool accepted,
    required bool skipped,
  }) {
    final gender =
        userStateManager.registrationDraft?.gender ?? Gender.unspecified;

    userStateManager.createProfile(
      onSuccess: (user, {required bool inviteApplied}) {
        locator<AnalyticsService>().capture(
          'onboarding_completed',
          properties: {'gender': gender.value, 'skipped': skipped},
        );
        final shouldPatch = MarketingEmailConsent.patchValueAfterOnboarding(
          accepted: accepted,
        );
        if (shouldPatch == true) {
          userStateManager.setMarketingOptIn(true).then((ok) {
            if (!ok) return;
            locator<AnalyticsService>().capture(
              'marketing_email_opt_in',
              properties: {'source': MarketingEmailConsent.sourceOnboarding},
            );
          });
        } else {
          locator<AnalyticsService>().capture(
            'marketing_email_declined',
            properties: {'source': MarketingEmailConsent.sourceOnboarding},
          );
        }
        if (!context.mounted || !inviteApplied) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Invite applied')));
      },
      onError: (error) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
      },
    );
  }
}
