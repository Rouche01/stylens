import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class MessageContent extends StatelessWidget {
  final String text;
  final TextStyle? baseStyle;

  const MessageContent({super.key, required this.text, this.baseStyle});

  @override
  Widget build(BuildContext context) {
    // Pre-process text to handle legacy FREE_LIMIT_REACHED keyword
    String processedText = text;
    if (text.contains('FREE_LIMIT_REACHED')) {
      processedText = text.replaceAll(
        'FREE_LIMIT_REACHED',
        '**Free Limit Reached**',
      );
    }

    final theme = Theme.of(context);
    final effectiveBaseStyle =
        theme.textTheme.bodyMedium?.merge(baseStyle) ??
        baseStyle ??
        theme.textTheme.bodyMedium;
    final headerStyle = effectiveBaseStyle?.copyWith(
      fontWeight: FontWeight.bold,
    );

    return MarkdownBody(
      data: processedText,
      selectable: true,
      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
        p: effectiveBaseStyle,
        strong: effectiveBaseStyle?.copyWith(fontWeight: FontWeight.bold),
        em: effectiveBaseStyle?.copyWith(fontStyle: FontStyle.italic),
        listBullet: effectiveBaseStyle,
        h1: headerStyle,
        h2: headerStyle,
        h3: headerStyle,
        h4: headerStyle,
        h5: headerStyle,
        h6: headerStyle,
        h1Padding: EdgeInsets.zero,
        h2Padding: EdgeInsets.zero,
        h3Padding: EdgeInsets.zero,
        h4Padding: EdgeInsets.zero,
        h5Padding: EdgeInsets.zero,
        h6Padding: EdgeInsets.zero,
        blockSpacing: 4,
      ),
    );
  }
}
