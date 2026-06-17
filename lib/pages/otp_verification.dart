import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gostylens/core/managers/auth_state_manager.dart';
import 'package:gostylens/core/managers/user_state_manager.dart';
import 'package:gostylens/widgets/primary_button.dart';
import 'package:gostylens/core/config/dependency_injection.dart';
import 'package:gostylens/widgets/auth_header.dart';
import 'package:pinput/pinput.dart';
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
  final supabase = locator<SupabaseClient>();

  late AuthStateManager _authStateManager;
  late UserStateManager _userStateManager;

  late final TapGestureRecognizer _resendTapRecognizer;

  @override
  void initState() {
    super.initState();
    _authStateManager = context.read<AuthStateManager>();
    _userStateManager = context.read<UserStateManager>();
    _resendTapRecognizer = TapGestureRecognizer();
    _otpController.addListener(_onOtpChanged);
  }

  void _onOtpChanged() {
    setState(() {});
  }

  void _onResend() {
    _authStateManager.initiateLoginWithOtp(
      widget.email,
      onSuccess: () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Verification code resent!')),
          );
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

  void _verifyOtp() {
    if (_formKey.currentState?.validate() ?? false) {
      _authStateManager.verifyOTP(
        widget.email,
        _otpController.text.trim(),
        onSuccess: (isNewUser) {
          if (!mounted) return;

          if (isNewUser) {
            _userStateManager.updateRegistrationDraft(email: widget.email);
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
  }

  @override
  void dispose() {
    _otpController.removeListener(_onOtpChanged);
    _otpController.dispose();
    _resendTapRecognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthStateManager>(
      builder: (context, authStateManager, _) {
        final canResend = authStateManager.canResendOTP;
        final resendSeconds = authStateManager.resendOTPSeconds;

        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surfaceDim,
          appBar: AppBar(
            backgroundColor: Theme.of(context).colorScheme.surfaceDim,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              iconSize: 28,
              onPressed: () => Navigator.pop(context),
              style: IconButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
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
                          AuthHeader(
                            topPadding: 24,
                            title: 'Check Your Inbox',
                            subtitle: Text.rich(
                              TextSpan(
                                text:
                                    'Your one-time verification code was sent to ',
                                children: [
                                  TextSpan(
                                    text: widget.email,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                  ),
                                  const TextSpan(
                                    text: '. Enter code to continue.',
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Pinput(
                            length: 6,
                            controller: _otpController,
                            autofocus: true,
                            autofillHints: const [AutofillHints.oneTimeCode],
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.done,
                            inputFormatters: const [_OtpDigitsFormatter()],
                            mainAxisAlignment: MainAxisAlignment.start,
                            separatorBuilder: (index) =>
                                const SizedBox(width: 6),
                            defaultPinTheme: PinTheme(
                              height: 60,
                              textStyle: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.outline.withValues(alpha: 0.5),
                                ),
                                color: Colors.white,
                              ),
                            ),
                            focusedPinTheme: PinTheme(
                              height: 60,
                              textStyle: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.primary,
                                  width: 2,
                                ),
                                color: Colors.white,
                              ),
                            ),
                            submittedPinTheme: PinTheme(
                              height: 60,
                              textStyle: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.05),
                              ),
                            ),
                            onCompleted: (_) => _verifyOtp(),
                          ),
                          const SizedBox(height: 32),
                          SizedBox(
                            width: double.infinity,
                            child: PrimaryButton(
                              label: 'Verify Code',
                              onPressed: authStateManager.isLoading
                                  ? null
                                  : _verifyOtp,
                              disabled:
                                  _otpController.text.length < 6 ||
                                  authStateManager.isLoading,
                              isLoading: authStateManager.isLoading,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text.rich(
                            TextSpan(
                              text: "Didn't receive the code? ",
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                fontSize: 14,
                              ),
                              children: [
                                TextSpan(
                                  text: canResend
                                      ? 'Resend OTP'
                                      : 'Resend OTP in ${resendSeconds}s...',
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                    decoration: canResend
                                        ? TextDecoration.underline
                                        : TextDecoration.none,
                                  ),
                                  recognizer: _resendTapRecognizer
                                    ..onTap = canResend ? _onResend : null,
                                ),
                              ],
                            ),
                            textAlign: TextAlign.left,
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _OtpDigitsFormatter extends TextInputFormatter {
  const _OtpDigitsFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final text = digits.length > 6 ? digits.substring(0, 6) : digits;
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
