import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:provider/provider.dart';
import 'package:gostylens/core/managers/auth_state_manager.dart';
import 'package:gostylens/core/managers/user_state_manager.dart';
import 'package:gostylens/navigation/app_routes.dart';
import 'package:gostylens/widgets/custom_form_field.dart';
import 'package:gostylens/widgets/custom_outlined_button.dart';
import 'package:gostylens/widgets/primary_button.dart';
import 'package:gostylens/widgets/auth_header.dart';
import 'package:gostylens/widgets/auth_legal_footer.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  late AuthStateManager _authStateManager;

  String? _validateEmail(String? value) {
    final email = value?.trim();
    if (email == null || email.isEmpty) {
      return 'Enter your email';
    }
    if (!email.contains('@') || !email.contains('.')) {
      return 'Enter a valid email';
    }
    return null;
  }

  bool get _isValidEmail {
    return _validateEmail(_emailController.text) == null;
  }

  @override
  void initState() {
    super.initState();
    _authStateManager = context.read<AuthStateManager>();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_formKey.currentState?.validate() ?? false) {
      await _authStateManager.initiateLoginWithOtp(
        _emailController.text.trim(),
        onSuccess: () {
          if (mounted) {
            FocusManager.instance.primaryFocus?.unfocus();
            TextInput.finishAutofillContext(shouldSave: true);
            final email = _emailController.text.trim();
            context.push(
              '${AppRoutes.otp}?email=${Uri.encodeQueryComponent(email)}',
            );
          }
        },
        onError: (error) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error)));
        },
      );
    }
  }

  Future<void> _handleGoogleSignIn() async {
    await _authStateManager.signInWithGoogle(
      onSuccess: (isNewUser, {email, name}) {
        if (mounted) {
          if (isNewUser) {
            context.read<UserStateManager>().updateRegistrationDraft(
              email: email,
              name: name,
            );
          }
        }
      },
      onError: (error) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error)));
        }
      },
    );
  }

  Future<void> _handleAppleSignIn() async {
    await _authStateManager.signInWithApple(
      onSuccess: (isNewUser, {email, name}) {
        if (mounted) {
          if (isNewUser) {
            context.read<UserStateManager>().updateRegistrationDraft(
              email: email,
              name: name,
            );
          }
        }
      },
      onError: (error) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error)));
        }
      },
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        const Expanded(child: Divider(thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Text('or', style: TextStyle(color: Colors.grey[600])),
        ),
        const Expanded(child: Divider(thickness: 1)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthStateManager>(
      builder: (context, authStateManager, child) {
        final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

        return Scaffold(
          key: const ValueKey('auth_page'),
          backgroundColor: Theme.of(context).colorScheme.surfaceDim,
          resizeToAvoidBottomInset: true,
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: AutofillGroup(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                          const AuthHeader(title: 'Login / Sign Up'),
                          CustomFormField(
                            controller: _emailController,
                            fieldType: FieldType.email,
                            hintText: 'Email',
                            validator: _validateEmail,
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: PrimaryButton(
                              label: 'Continue',
                              onPressed: authStateManager.isLoading
                                  ? null
                                  : _login,
                              disabled:
                                  !_isValidEmail || authStateManager.isLoading,
                              isLoading: authStateManager.isLoading,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildDivider(),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: CustomOutlinedButton(
                              icon: Image.asset(
                                'assets/icon/google_logo.png',
                                height: 20,
                                width: 20,
                              ),
                              label: 'Continue with Google',
                              onPressed: authStateManager.isLoading
                                  ? null
                                  : _handleGoogleSignIn,
                            ),
                          ),
                          if (Platform.isIOS) ...[
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: CustomOutlinedButton(
                                icon: const Icon(Icons.apple, size: 24),
                                label: 'Continue with Apple',
                                onPressed: authStateManager.isLoading
                                    ? null
                                    : _handleAppleSignIn,
                              ),
                            ),
                          ],
                          const SizedBox(height: 32),
                          if (keyboardOpen) const AuthLegalFooter(),
                        ],
                      ),
                    ),
                    ),
                  ),
                ),
                if (!keyboardOpen) const AuthLegalFooter(),
              ],
            ),
          ),
        );
      },
    );
  }
}
