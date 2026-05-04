import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:gostylens/constants/links.dart';
import 'package:url_launcher/url_launcher.dart';

class AuthLegalFooter extends StatefulWidget {
  const AuthLegalFooter({super.key});

  @override
  State<AuthLegalFooter> createState() => _AuthLegalFooterState();
}

class _AuthLegalFooterState extends State<AuthLegalFooter> {
  late TapGestureRecognizer _termsRecognizer;
  late TapGestureRecognizer _privacyRecognizer;

  @override
  void initState() {
    super.initState();
    _termsRecognizer = TapGestureRecognizer()
      ..onTap = () => _launchURL(Links.termsOfUse);
    _privacyRecognizer = TapGestureRecognizer()
      ..onTap = () => _launchURL(Links.privacyPolicy);
  }

  @override
  void dispose() {
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    super.dispose();
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.inAppWebView);
      }
    } catch (e) {
      debugPrint('Could not launch $url: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Text.rich(
        TextSpan(
          text: 'By continuing you agree to GoStylens ',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
          children: [
            TextSpan(
              text: 'Terms of Service',
              recognizer: _termsRecognizer,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
                decoration: TextDecoration.underline,
              ),
            ),
            const TextSpan(text: ' and acknowledge you\'ve read our '),
            TextSpan(
              text: 'Privacy Policy',
              recognizer: _privacyRecognizer,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
                decoration: TextDecoration.underline,
              ),
            ),
          ],
        ),
        textAlign: TextAlign.left,
      ),
    );
  }
}
