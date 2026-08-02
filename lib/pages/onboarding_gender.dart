import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gostylens/widgets/custom_outlined_button.dart';
import 'package:gostylens/widgets/primary_button.dart';
import 'package:gostylens/widgets/step_progress_bar.dart';
import 'package:gostylens/core/managers/user_state_manager.dart';
import 'package:gostylens/models/api_responses/gender.dart';
import 'package:provider/provider.dart';

class OnboardingGenderPage extends StatefulWidget {
  const OnboardingGenderPage({super.key});

  @override
  State<OnboardingGenderPage> createState() => _OnboardingGenderPageState();
}

class _OnboardingGenderPageState extends State<OnboardingGenderPage> {
  int? _selectedIndex = 0;

  final List<_GenderOption> _options = [
    _GenderOption('Man', Gender.male, Icons.male),
    _GenderOption('Woman', Gender.female, Icons.female),
    _GenderOption('Non-binary', Gender.nonBinary, Icons.transgender),
    _GenderOption(
      'Prefer not to say',
      Gender.unspecified,
      Icons.person_outline,
    ),
  ];

  void _onContinue() {
    if (_selectedIndex == null) return;

    final gender = _options[_selectedIndex!].gender;

    final userStateManager = context.read<UserStateManager>();
    userStateManager.updateRegistrationDraft(gender: gender);

    userStateManager.createProfile(
      onSuccess: (user, {required bool inviteApplied}) {
        if (!mounted || !inviteApplied) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invite applied')),
        );
      },
      onError: (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
      },
    );
  }

  void _onSkip() {
    final userStateManager = context.read<UserStateManager>();
    userStateManager.updateRegistrationDraft(gender: Gender.unspecified);

    userStateManager.createProfile(
      onSuccess: (user, {required bool inviteApplied}) {
        if (!mounted || !inviteApplied) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invite applied')),
        );
      },
      onError: (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceDim,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton(
                    icon: FaIcon(
                      FontAwesomeIcons.arrowLeftLong,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: StepProgressBar(
                      totalSteps: 2,
                      currentStep: 2,
                      activeColor: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Text(
                'Tell us a bit about yourself',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                  fontFamily: 'ClashDisplay',
                  height: 1.2,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.left,
              ),
              const SizedBox(height: 32),
              ...List.generate(_options.length, (index) {
                final option = _options[index];
                final isSelected = _selectedIndex == index;
                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  child: Material(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary.withAlpha(50)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        setState(() {
                          _selectedIndex = index;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 18,
                          horizontal: 16,
                        ),
                        child: Row(
                          children: [
                            if (option.icon != null)
                              Icon(option.icon, color: Colors.black54)
                            else
                              const SizedBox(width: 24),
                            if (option.icon != null) const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                option.label,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                            if (isSelected)
                              Icon(
                                Icons.check,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 8),
              Text(
                'Gender helps us give better styling advice.',
                style: TextStyle(
                  fontSize: 15,
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(150),
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.left,
              ),
              const Spacer(),
              Consumer<UserStateManager>(
                builder: (context, userStateManager, child) {
                  return Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: CustomOutlinedButton(
                          label: 'Skip',
                          onPressed: userStateManager.operationState.isCreating
                              ? null
                              : _onSkip,
                          disabled: userStateManager.operationState.isCreating,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: PrimaryButton(
                          label: 'Finish',
                          onPressed: userStateManager.operationState.isCreating
                              ? null
                              : _onContinue,
                          disabled:
                              _selectedIndex == null ||
                              userStateManager.operationState.isCreating,
                          isLoading: userStateManager.operationState.isCreating,
                          icon: const Icon(Icons.arrow_forward, size: 20),
                          iconAlignment: IconAlignment.end,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _GenderOption {
  final String label;
  final Gender gender;
  final IconData? icon;
  const _GenderOption(this.label, this.gender, this.icon);
}
