import 'package:flutter/material.dart';
import 'package:gostylens/widgets/animated_typing_dots.dart';
import 'package:gostylens/widgets/image_with_fallback.dart';
import 'package:gostylens/models/style_analysis_session_message.dart';

class MessageBubble extends StatelessWidget {
  final StyleAnalysisSessionMessage message;

  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
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
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: SizedBox(width: 40, child: AnimatedTypingDots(size: 6)),
          ),
        ],
      );
    }

    return Align(
      alignment: message.isUserMessage
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        padding: EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
          minWidth: 100,
        ),
        decoration: BoxDecoration(
          color: message.isUserMessage
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.imageFile != null || message.remoteImage != null) ...[
              ImageWithFallback(
                imageFile: message.imageFile,
                remoteImage: message.remoteImage,
                width: 200,
                height: 200,
                fit: BoxFit.cover,
                borderRadius: BorderRadius.circular(8),
              ),
            ],
            if (message.text != null) ...[
              if (message.imageFile != null || message.remoteImage != null)
                SizedBox(height: 8),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth:
                      (message.imageFile != null || message.remoteImage != null)
                      ? 200
                      : double.infinity,
                ),
                child: Text(
                  message.text!,
                  style: TextStyle(
                    color: message.isUserMessage
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
