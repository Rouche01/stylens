import 'package:flutter/material.dart';

class MessageInput extends StatelessWidget {
  final TextEditingController messageController;
  final VoidCallback onSendMessage;
  final bool isSendDisabled;

  const MessageInput({
    super.key,
    required this.messageController,
    required this.onSendMessage,
    this.isSendDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: messageController,
              decoration: InputDecoration(
                hintText: 'Type your message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              onSubmitted: (_) => isSendDisabled ? null : onSendMessage(),
            ),
          ),
          SizedBox(width: 8),
          IconButton(
            onPressed: isSendDisabled ? null : onSendMessage,
            icon: Icon(Icons.send),
            style: IconButton.styleFrom(
              backgroundColor: isSendDisabled
                  ? Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.12)
                  : Theme.of(context).colorScheme.primary,
              foregroundColor: isSendDisabled
                  ? Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.38)
                  : Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
