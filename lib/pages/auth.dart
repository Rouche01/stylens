import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gostylens/core/managers/auth_state_manager.dart';
import 'package:gostylens/core/managers/user_state_manager.dart';
import 'package:gostylens/pages/otp_verification.dart';
import 'package:gostylens/widgets/custom_form_field.dart';
import 'package:gostylens/widgets/custom_outlined_button.dart';
import 'package:gostylens/widgets/primary_button.dart';

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

  Future<void> _login() async {
    if (_formKey.currentState?.validate() ?? false) {
      await _authStateManager.initiateLoginWithOtp(
        _emailController.text.trim(),
        onSuccess: () {
          if (mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) =>
                    OtpVerificationPage(email: _emailController.text.trim()),
              ),
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
          // No need to navigate manually; AuthGate handles it.
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
  void dispose() {
    _emailController.dispose();
    super.dispose();
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
        return Scaffold(
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 32),
                      Image.asset(
                        'assets/icon/icon.png',
                        width: 55,
                        height: 55,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Login / Sign Up',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                          fontFamily: 'ClashDisplay',
                        ),
                      ),
                      const SizedBox(height: 32),
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
                          onPressed: authStateManager.isLoading ? null : _login,
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
                          onPressed: () {
                            // TODO: Implement Google Sign-in
                          },
                        ),
                      ),
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
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),
          backgroundColor: Theme.of(context).colorScheme.surfaceDim,
        );
      },
    );
  }
}
