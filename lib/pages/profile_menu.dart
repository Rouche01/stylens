import 'package:flutter/material.dart';
import 'package:gostylens/core/managers/auth_state_manager.dart';
import 'package:gostylens/core/managers/user_state_manager.dart';
import 'package:gostylens/widgets/auth_gate.dart';
import 'package:provider/provider.dart';

class ProfileMenuPage extends StatelessWidget {
  Future<void> _logout(BuildContext context) async {
    context.read<AuthStateManager>().logOut(
      onSuccess: () {
        // Clear local user state
        context.read<UserStateManager>().clearUser();

        if (context.mounted) {
          // Re-initialize the app from the root AuthGate
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const AuthGate()),
            (route) => false,
          );
        }
      },
      onError: (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Logout failed: $error')));
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(
              'Profile & Settings',
              style: TextStyle(
                fontFamily: 'ClashDisplay',
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
        titleSpacing: 0,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Spacer(),
            Consumer<AuthStateManager>(
              builder: (context, authStateManager, child) {
                return SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: authStateManager.isLoading
                        ? null
                        : () => _logout(context),
                    icon: authStateManager.isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.grey,
                            ),
                          )
                        : const Icon(Icons.logout, color: Colors.redAccent),
                    label: Text(
                      authStateManager.isLoading ? 'Logging out...' : 'Log out',
                      style: TextStyle(
                        color: authStateManager.isLoading
                            ? Colors.grey
                            : Colors.redAccent,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: authStateManager.isLoading
                            ? Colors.grey
                            : Colors.redAccent,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
