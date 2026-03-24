import 'package:flutter/material.dart';
import 'package:gostylens/constants/ux_messages.dart';
import 'dart:io';

class MessageInput extends StatelessWidget {
  final TextEditingController messageController;
  final VoidCallback onSendMessage;
  final bool isSendDisabled;
  final bool isTextFieldDisabled;
  final shouldAutoFocus = true;
  final FocusNode? focusNode;
  final String? placeholder;
  final VoidCallback? onAttachPressed;
  final File? attachedImage;
  final VoidCallback? onRemoveImage;

  const MessageInput({
    super.key,
    required this.messageController,
    required this.onSendMessage,
    this.isSendDisabled = false,
    this.isTextFieldDisabled = false,
    this.focusNode,
    this.placeholder = UxMessages.messagePlaceholderDefault,
    this.onAttachPressed,
    this.attachedImage,
    this.onRemoveImage,
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (attachedImage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      image: DecorationImage(
                        image: FileImage(attachedImage!),
                        fit: BoxFit.cover,
                      ),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.outline.withValues(alpha: 0.4),
                        width: 1,
                      ),
                    ),
                  ),
                  Positioned(
                    top: -6,
                    right: -6,
                    child: GestureDetector(
                      onTap: onRemoveImage,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              if (onAttachPressed != null) ...[
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withValues(alpha: 0.8),
                      width: 1.5,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: isTextFieldDisabled ? null : onAttachPressed,
                    icon: Icon(
                      Icons.add_a_photo,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: TextField(
                  controller: messageController,
                  focusNode: focusNode,
                  autofocus: shouldAutoFocus,
                  enabled: !isTextFieldDisabled,
                  decoration: InputDecoration(
                    hintText: placeholder,
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
        ],
      ),
    );
  }
}
