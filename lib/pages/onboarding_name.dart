import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gostylens/core/config/dependency_injection.dart';
import 'package:gostylens/core/managers/invite_code_store.dart';
import 'package:gostylens/navigation/app_routes.dart';
import 'package:gostylens/widgets/custom_form_field.dart';
import 'package:gostylens/widgets/primary_button.dart';
import 'package:gostylens/widgets/step_progress_bar.dart';
import 'package:gostylens/core/managers/user_state_manager.dart';
import 'package:provider/provider.dart';

class OnboardingNamePage extends StatefulWidget {
  const OnboardingNamePage({super.key});

  @override
  State<OnboardingNamePage> createState() => _OnboardingNamePageState();
}

class _OnboardingNamePageState extends State<OnboardingNamePage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _inviteController = TextEditingController();
  late final UserStateManager _userStateManager;

  bool get _isNameEmpty => _nameController.text.trim().isEmpty;

  @override
  void initState() {
    super.initState();
    _userStateManager = context.read<UserStateManager>();

    // Pre-fill name if it exists in the registration draft (from Google/Apple Sign-In)
    _applyDraftNameIfNeeded();
    _loadPendingInviteCode();

    // Cover race where draft is written after this page mounts.
    _userStateManager.addListener(_onUserStateChanged);

    _nameController.addListener(() {
      setState(() {});
    });
  }

  Future<void> _loadPendingInviteCode() async {
    final pending = await locator<InviteCodeStore>().read();
    if (!mounted || pending == null) return;
    if (_inviteController.text.trim().isNotEmpty) return;
    _inviteController.text = pending;
  }

  void _onUserStateChanged() {
    if (!mounted) return;
    _applyDraftNameIfNeeded();
  }

  /// Applies [registrationDraft].name when the field is still empty.
  void _applyDraftNameIfNeeded() {
    if (_nameController.text.trim().isNotEmpty) return;
    final draft = _userStateManager.registrationDraft;
    if (draft != null && draft.name.isNotEmpty) {
      _nameController.text = draft.name;
    }
  }

  @override
  void dispose() {
    _userStateManager.removeListener(_onUserStateChanged);
    _nameController.dispose();
    _inviteController.dispose();
    super.dispose();
  }

  Future<void> _onContinue() async {
    context.read<UserStateManager>().updateRegistrationDraft(
      name: _nameController.text.trim(),
    );

    await locator<InviteCodeStore>().save(_inviteController.text);

    if (!mounted) return;
    context.push(AppRoutes.onboardingGender);
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
              StepProgressBar(
                totalSteps: 2,
                currentStep: 1,
                activeColor: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 50),
              Text(
                'What should we call you?',
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
              CustomFormField(
                controller: _nameController,
                fieldType: FieldType.text,
                hintText: 'Enter name',
              ),
              const SizedBox(height: 16),
              Text(
                'This helps us personalize your tips.',
                style: TextStyle(
                  fontSize: 15,
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(150),
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.left,
              ),
              const SizedBox(height: 24),
              CustomFormField(
                controller: _inviteController,
                fieldType: FieldType.text,
                hintText: 'Invite code (optional)',
              ),
              const Spacer(),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  label: 'Continue',
                  onPressed: _onContinue,
                  disabled: _isNameEmpty,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
