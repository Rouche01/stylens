import 'package:flutter/material.dart';

class FormattedErrorText extends StatelessWidget {
  final String text;
  final TextStyle? baseStyle;

  const FormattedErrorText({super.key, required this.text, this.baseStyle});

  @override
  Widget build(BuildContext context) {
    // If the text doesn't contain the keyword, just return standard text.
    if (!text.contains('FREE_LIMIT_REACHED')) {
      return Text(text, style: baseStyle);
    }

    // Split the string by the keyword
    final parts = text.split('FREE_LIMIT_REACHED');
    final List<InlineSpan> spans = [];

    for (int i = 0; i < parts.length; i++) {
      // Add the normal text piece
      if (parts[i].isNotEmpty) {
        spans.add(TextSpan(text: parts[i]));
      }

      // If we aren't at the end of the array, add the bold replacement
      if (i < parts.length - 1) {
        spans.add(
          TextSpan(
            text: 'Free Limit Reached',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        );
      }
    }

    return RichText(
      text: TextSpan(
        style: baseStyle ?? DefaultTextStyle.of(context).style,
        children: spans,
      ),
    );
  }
}
