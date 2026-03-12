import 'package:flutter/material.dart';
import 'package:gostylens/core/managers/user_state_manager.dart';
import 'package:gostylens/models/api_responses/gender.dart';
import 'package:provider/provider.dart';

class ProfileEditSheet extends StatefulWidget {
  const ProfileEditSheet({super.key});

  /// Shows the profile edit bottom sheet.
  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.tertiary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const ProfileEditSheet(),
    );
  }

  @override
  State<ProfileEditSheet> createState() => _ProfileEditSheetState();
}

class _ProfileEditSheetState extends State<ProfileEditSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _nicknameController;
  Gender? _selectedGender;

  @override
  void initState() {
    super.initState();
    final user = context.read<UserStateManager>().currentUser;
    _nameController = TextEditingController(text: user?.name ?? '');
    _nicknameController = TextEditingController(text: user?.nickname ?? '');
    _selectedGender = user?.gender;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  String _genderLabel(Gender gender) {
    switch (gender) {
      case Gender.male:
        return 'Male';
      case Gender.female:
        return 'Female';
      case Gender.nonBinary:
        return 'Non-binary';
      case Gender.unspecified:
        return 'Prefer not to say';
    }
  }

  InputDecoration _inputDecoration(BuildContext context, String label) {
    final cs = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: cs.primary.withValues(alpha: 0.6),
      ),
      filled: true,
      fillColor: cs.primary.withValues(alpha: 0.05),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: cs.primary.withValues(alpha: 0.1),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: cs.primary.withValues(alpha: 0.1),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.primary),
      ),
    );
  }

  void _handleUpdate() {
    final name = _nameController.text.trim();
    final nickname = _nicknameController.text.trim();
    final userState = context.read<UserStateManager>();

    userState.updateProfile(
      name: name.isNotEmpty ? name : null,
      nickname: nickname.isNotEmpty ? nickname : null,
      gender: _selectedGender?.value,
      onSuccess: (_) {
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated!')),
          );
        }
      },
      onError: (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error)),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: MediaQuery.of(context).size.height * 0.5,
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
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
              'Profile',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                fontFamily: 'ClashDisplay',
                color: cs.primary,
              ),
            ),
            const SizedBox(height: 20),

            // Full name
            TextField(
              controller: _nameController,
              decoration: _inputDecoration(context, 'Full name'),
              style: TextStyle(color: cs.primary),
            ),
            const SizedBox(height: 16),

            // Nickname
            TextField(
              controller: _nicknameController,
              decoration: _inputDecoration(context, 'What should we call you?'),
              style: TextStyle(color: cs.primary),
            ),
            const SizedBox(height: 16),

            // Gender dropdown
            DropdownButtonFormField<Gender>(
              value: _selectedGender,
              decoration: _inputDecoration(context, 'Gender'),
              dropdownColor: cs.tertiary,
              style: TextStyle(color: cs.primary, fontSize: 16),
              icon: Icon(
                Icons.keyboard_arrow_down,
                color: cs.primary.withValues(alpha: 0.5),
              ),
              items: Gender.values.map((gender) {
                return DropdownMenuItem<Gender>(
                  value: gender,
                  child: Text(_genderLabel(gender)),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedGender = value);
              },
            ),
            const SizedBox(height: 24),

            // Update button
            Consumer<UserStateManager>(
              builder: (context, userState, _) {
                return SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: userState.isLoading ? null : _handleUpdate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: userState.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Update Profile'),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            // Cancel button
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: 15,
                    color: cs.primary.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
