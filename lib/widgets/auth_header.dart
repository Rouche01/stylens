import 'package:flutter/material.dart';

class AuthHeader extends StatelessWidget {
  final String title;
  final Widget? subtitle;
  final double? topPadding;

  const AuthHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.topPadding,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: topPadding ?? 50),
        Image.asset('assets/icon/icon.png', width: 45, height: 45),
        const SizedBox(height: 32),
        Text(
          title,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.primary,
            fontFamily: 'ClashDisplay',
            letterSpacing: -0.5,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          DefaultTextStyle(
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
            child: subtitle!,
          ),
        ],
        const SizedBox(height: 32),
      ],
    );
  }
}
