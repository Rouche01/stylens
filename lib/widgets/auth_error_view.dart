import 'package:flutter/material.dart';
import 'package:gostylens/models/api_responses/api_response.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:gostylens/core/config/dependency_injection.dart';

class AuthErrorView extends StatelessWidget {
  final ErrorData? error;
  final VoidCallback onRetry;
  final String? fallbackTitle;
  final String? fallbackMessage;

  const AuthErrorView({
    super.key,
    this.error,
    required this.onRetry,
    this.fallbackTitle,
    this.fallbackMessage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Scaffold(
      backgroundColor: cs.surfaceDim,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              color: cs.error.withValues(alpha: 0.8),
              size: 72,
            ),
            const SizedBox(height: 24),
            Text(
              error?.toFriendlyTitle() ?? fallbackTitle ?? 'Unable to Connect',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error?.toFriendlyMessage() ??
                  fallbackMessage ??
                  'We were unable to load your profile. Please check your connection and try again.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                ),
                child: Text(
                  'Retry',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ),
            ),
            TextButton(
              onPressed: () => locator<SupabaseClient>().auth.signOut(),
              child: Text(
                'Back to Login',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: cs.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
