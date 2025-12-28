import 'package:flutter/material.dart';
import 'package:stylens_app/widgets/image_with_fallback.dart';
import '../models/chat_message.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: 16),
        padding: EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: message.isUser
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
              if (message.imageFile != null) SizedBox(height: 8),
              Text(
                message.text!,
                style: TextStyle(
                  color: message.isUser
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
