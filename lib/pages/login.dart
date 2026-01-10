import 'package:flutter/material.dart';
import 'package:gostylens/pages/home.dart';
import 'package:gostylens/widgets/custom_form_field.dart';
import 'package:gostylens/widgets/custom_outlined_button.dart';
import 'package:gostylens/widgets/primary_button.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isUsingEmail = false;

  void _login() {
    if (_formKey.currentState?.validate() ?? false) {
      if (!_isUsingEmail) {
        setState(() {
          _isUsingEmail = true;
        });
      } else {
        // Handle login with email and password
        print('Logging in as ${_emailController.text} with password');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logging in as ${_emailController.text}')),
        );
      }
    }
  }

  void _navigateToHome() {
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (context) => MyHomePage()));
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
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
                  Image.asset('assets/icon/icon.png', width: 72, height: 72),
                  const SizedBox(height: 10),
                  const Text(
                    'Login or Sign Up',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 32),
                  CustomFormField(
                    controller: _emailController,
                    fieldType: FieldType.email,
                    hintText: 'Email',
                    validator: (value) => value != null && value.contains('@')
                        ? null
                        : 'Enter a valid email',
                  ),
                  if (_isUsingEmail) ...[
                    const SizedBox(height: 16),
                    CustomFormField(
                      controller: _passwordController,
                      fieldType: FieldType.password,
                      hintText: 'Password',
                      validator: (value) => value != null && value.length >= 6
                          ? null
                          : 'Enter at least 6 characters',
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: PrimaryButton(label: 'Continue', onPressed: _login),
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
                      onPressed: _navigateToHome,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: CustomOutlinedButton(
                      icon: const Icon(Icons.apple, size: 24),
                      label: 'Continue with Apple',
                      onPressed: _navigateToHome,
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
  }
}
