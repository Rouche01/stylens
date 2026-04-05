import 'package:flutter/material.dart';
import 'package:gostylens/widgets/animated_typing_dots.dart';
import 'package:gostylens/widgets/formatted_error_text.dart';
import 'package:gostylens/models/style_analysis_session_message.dart';
import 'package:gostylens/widgets/message_image_gallery.dart';

class ErrorAction {
  final String label;
  final TextStyle? labelStyle;
  final Icon? icon;
  final bool showIcon;
  final VoidCallback? handleAction;

  const ErrorAction({
    this.label = 'Retry',
    this.labelStyle,
    this.icon,
    this.showIcon = true,
    this.handleAction,
  });
}

class MessageBubble extends StatelessWidget {
  final StyleAnalysisSessionMessage message;
  final ErrorAction errorAction;

  const MessageBubble({
    super.key,
    required this.message,
    this.errorAction = const ErrorAction(),
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final totalImages = message.images?.length ?? 0;
    final hasImage = totalImages > 0;
    if (message.isLoading) {
      return Row(
        mainAxisAlignment: message.isUserMessage
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: message.isUserMessage
                  ? colors.primary
                  : colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: SizedBox(width: 40, child: AnimatedTypingDots(size: 6)),
          ),
        ],
      );
    }

    final TextStyle derivedErrorActionLabelStyle =
        errorAction.labelStyle ??
        TextStyle(
          color: colors.error,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        );

    final Icon? derivedErrorActionIcon = errorAction.showIcon
        ? (errorAction.icon ??
              Icon(Icons.refresh, size: 16, color: colors.error))
        : null;

    return Align(
      alignment: message.isUserMessage
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: message.isUserMessage
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(12),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
              minWidth: 100,
            ),
            decoration: BoxDecoration(
              color: message.isError
                  ? colors.errorContainer
                  : (message.isUserMessage
                        ? colors.primaryContainer
                        : colors.surfaceContainerHighest),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasImage) ...[
                  MessageImageGallery(images: message.images),
                ],
                if (message.displayText case final displayText?) ...[
                  if (hasImage) SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: totalImages == 1 ? 200 : double.infinity,
                    ),
                    child: FormattedErrorText(
                      text: displayText,
                      baseStyle: TextStyle(
                        color: message.isError
                            ? colors.onErrorContainer
                            : (message.isUserMessage
                                  ? colors.onPrimary
                                  : colors.onSurfaceVariant),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (message.isError && errorAction.handleAction != null)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: GestureDetector(
                onTap: errorAction.handleAction,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (derivedErrorActionIcon != null) ...[
                      derivedErrorActionIcon,
                    ],
                    const SizedBox(width: 4),
                    Text(
                      errorAction.label,
                      style: derivedErrorActionLabelStyle,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
