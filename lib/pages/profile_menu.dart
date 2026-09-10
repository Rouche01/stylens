import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gostylens/constants/links.dart';
import 'package:gostylens/core/managers/auth_state_manager.dart';
import 'package:gostylens/core/managers/user_state_manager.dart';
import 'package:gostylens/navigation/app_routes.dart';
import 'package:gostylens/widgets/profile_edit_sheet.dart';
import 'package:gostylens/widgets/settings_menu_group.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfileMenuPage extends StatelessWidget {
  const ProfileMenuPage({super.key});

  Future<void> _logout(BuildContext context) async {
    final authState = context.read<AuthStateManager>();

    authState.logOut(
      onError: (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Logout failed: $error')));
        }
      },
    );
  }

  void _showProfileEditSheet(BuildContext context) {
    ProfileEditSheet.show(context);
  }

  void _showDeleteAccountDialog(
    BuildContext context,
    UserStateManager userState,
  ) {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        actionsPadding: const EdgeInsets.only(right: 16, bottom: 8, top: 0),
        backgroundColor: cs.tertiary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Account',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: cs.primary,
            fontSize: 18,
          ),
        ),
        content: SizedBox(
          width: MediaQuery.of(dialogContext).size.width,
          child: Text(
            'Deleting your account is permanent. You will have no way of recovering your account or previous styling histories.',
            style: TextStyle(
              color: cs.primary.withValues(alpha: 0.8),
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: cs.primary.withValues(alpha: 0.6)),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              userState.deleteAccount(
                onError: (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(error)));
                  }
                },
                onSuccess: () {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Account deleted successfully.'),
                      ),
                    );
                  }
                },
              );
            },
            child: const Text(
              'I understand',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(
              'Profile & Settings',
              style: TextStyle(
                fontFamily: 'ClashDisplay',
                fontWeight: FontWeight.w600,
                color: cs.primary,
              ),
            ),
          ],
        ),
        titleSpacing: 0,
        backgroundColor: cs.tertiary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
          color: cs.primary,
        ),
      ),
      backgroundColor: cs.tertiary,
      body: Consumer<UserStateManager>(
        builder: (context, userState, _) {
          final user = userState.currentUser;
          final displayName = user?.name ?? 'User';
          final email = user?.email ?? '';

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: [
                const SizedBox(height: 24),
                CircleAvatar(
                  radius: 50,
                  backgroundColor: cs.secondary.withValues(alpha: 0.4),
                  child: Icon(
                    Icons.person,
                    size: 56,
                    color: cs.primary.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  displayName,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: cs.primary,
                    fontFamily: 'ClashDisplay',
                  ),
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: TextStyle(
                      fontSize: 14,
                      color: cs.primary.withValues(alpha: 0.7),
                    ),
                  ),
                ],
                const SizedBox(height: 32),

                SettingsMenuGroup(
                  items: [
                    SettingsMenuItem(
                      icon: Icons.person_outline,
                      label: 'Profile',
                      onTap: () => _showProfileEditSheet(context),
                    ),
                    SettingsMenuItem(
                      icon: Icons.credit_card,
                      label: 'Billing / Plan',
                      onTap: () {
                        context.push(AppRoutes.billing);
                      },
                    ),
                    SettingsMenuItem(
                      icon: Icons.notifications_outlined,
                      label: 'Notifications',
                      onTap: () {
                        context.push(AppRoutes.profileNotifications);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                SettingsMenuGroup(
                  items: [
                    SettingsMenuItem(
                      icon: Icons.help_outline,
                      label: 'Support & FAQs',
                      onTap: () => launchUrl(
                        Uri.parse(Links.support),
                        mode: LaunchMode.inAppBrowserView,
                      ),
                    ),
                    SettingsMenuItem(
                      icon: Icons.description_outlined,
                      label: 'Terms & Conditions',
                      onTap: () => launchUrl(
                        Uri.parse(Links.termsOfUse),
                        mode: LaunchMode.inAppBrowserView,
                      ),
                    ),
                    SettingsMenuItem(
                      icon: Icons.shield_outlined,
                      label: 'Privacy Policy',
                      onTap: () => launchUrl(
                        Uri.parse(Links.privacyPolicy),
                        mode: LaunchMode.inAppBrowserView,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Consumer<AuthStateManager>(
                  builder: (context, authStateManager, _) {
                    return SettingsMenuGroup(
                      items: [
                        SettingsMenuItem(
                          icon: Icons.delete_outline,
                          label: 'Delete account',
                          color: Colors.redAccent,
                          onTap: () =>
                              _showDeleteAccountDialog(context, userState),
                        ),
                        SettingsMenuItem(
                          icon: Icons.logout,
                          label: authStateManager.isLoading
                              ? 'Logging out...'
                              : 'Log out',
                          color: Colors.redAccent,
                          trailing: authStateManager.isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.redAccent,
                                  ),
                                )
                              : null,
                          onTap: authStateManager.isLoading
                              ? null
                              : () => _logout(context),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }
}
