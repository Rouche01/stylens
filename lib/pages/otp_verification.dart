import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:gostylens/core/managers/auth_state/index.dart';
import 'package:gostylens/pages/onboarding_name.dart';
import 'package:gostylens/widgets/custom_form_field.dart';
import 'package:gostylens/widgets/primary_button.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OtpVerificationPage extends StatefulWidget {
  final String email;
  const OtpVerificationPage({super.key, required this.email});

  @override
  State<OtpVerificationPage> createState() => _OtpVerificationPageState();
}

class _OtpVerificationPageState extends State<OtpVerificationPage> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();
  final supabase = Supabase.instance.client;

  late AuthStateManager _authStateManager;
  bool get _isOtpEmpty => _otpController.text.trim().isEmpty;

  late final TapGestureRecognizer _resendTapRecognizer;

  @override
  void initState() {
    super.initState();
    _authStateManager = context.read<AuthStateManager>();
    _resendTapRecognizer = TapGestureRecognizer()
      ..onTap = _authStateManager.canResendOTP ? _onResend : null;
  }

  void _onResend() {
    // Implement resend OTP logic here
  }

  Future<void> _verifyOtp() async {
    if (_formKey.currentState?.validate() ?? false) {
      // await supabase.auth.signInWithOtp(email: _emailController.text);

      // // Handle login with email and password
      // print('Logging in as ${_emailController.text} with password');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('OTP ${_otpController.text} verified successfully.'),
          ),
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => OnboardingNamePage()),
        );
      }
    }
  }

  @override
  void dispose() {
    _otpController.dispose();
    _resendTapRecognizer.dispose();
    _authStateManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthStateManager>(
      builder: (context, authStateManager, _) {
        final canResend = authStateManager.canResendOTP;
        final resendSeconds = authStateManager.resendOTPSeconds;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              'Login / Sign up',
              style: TextStyle(
                fontFamily: 'ClashDisplay',
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            backgroundColor: Theme.of(context).colorScheme.surfaceDim,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
              style: IconButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 10,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/icon/icon.png',
                        width: 55,
                        height: 55,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Check Your Inbox',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                          fontFamily: 'ClashDisplay',
                        ),
                      ),
                      Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(
                              text:
                                  'Your one-time verification code was sent to ',
                              style: TextStyle(fontWeight: FontWeight.normal),
                            ),
                            TextSpan(
                              text: widget.email,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const TextSpan(
                              text: '. Enter the code below to continue.',
                              style: TextStyle(fontWeight: FontWeight.normal),
                            ),
                          ],
                        ),
                        style: TextStyle(color: Colors.grey[700]),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      CustomFormField(
                        controller: _otpController,
                        fieldType: FieldType.number,
                        hintText: 'Verification Code',
                        validator: (value) => value != null && value.isNotEmpty
                            ? null
                            : 'Please enter the verification code',
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        child: PrimaryButton(
                          label: 'Verify Code',
                          onPressed: _verifyOtp,
                          disabled: _isOtpEmpty,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text.rich(
                        TextSpan(
                          text: "Didn't receive the code? ",
                          style: TextStyle(color: Colors.grey[700]),
                          children: [
                            TextSpan(
                              text: canResend
                                  ? 'Resend OTP'
                                  : 'Resend OTP in ${resendSeconds}s...',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w600,
                                decoration: canResend
                                    ? TextDecoration.underline
                                    : TextDecoration.none,
                              ),
                              recognizer: _resendTapRecognizer,
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
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
