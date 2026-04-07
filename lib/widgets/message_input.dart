import 'package:flutter/material.dart';
import 'package:gostylens/constants/ux_messages.dart';
import 'dart:io';

class MessageInput extends StatelessWidget {
  final TextEditingController messageController;
  final VoidCallback onSendMessage;
  final bool isSendDisabled;
  final bool isTextFieldDisabled;
  final bool autofocus;
  final FocusNode? focusNode;
  final String? placeholder;
  final VoidCallback? onAttachPressed;
  final List<File>? attachedImages;
  final void Function(int index)? onRemoveImage;
  final void Function(int index)? onPreviewImage;

  const MessageInput({
    super.key,
    required this.messageController,
    required this.onSendMessage,
    this.isSendDisabled = false,
    this.isTextFieldDisabled = false,
    this.autofocus = false,
    this.focusNode,
    this.placeholder = UxMessages.messagePlaceholderDefault,
    this.onAttachPressed,
    this.attachedImages,
    this.onRemoveImage,
    this.onPreviewImage,
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
          if (attachedImages != null && attachedImages!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: SizedBox(
                height: 96,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: attachedImages!.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final file = attachedImages![index];
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        GestureDetector(
                          onTap: () => onPreviewImage?.call(index),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              width: 84,
                              height: 84,
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                                border: Border.all(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.outline.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Image.file(
                                file,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Center(
                                    child: Icon(
                                      Icons.error_outline,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.error,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: -6,
                          right: -6,
                          child: GestureDetector(
                            onTap: () => onRemoveImage?.call(index),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.7),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1.5,
                                ),
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
                    );
                  },
                ),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (onAttachPressed != null) ...[
                IconButton(
                  onPressed: isTextFieldDisabled ? null : onAttachPressed,
                  icon: Icon(Icons.add),
                  style: IconButton.styleFrom(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.25),
                    foregroundColor: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: TextField(
                  controller: messageController,
                  focusNode: focusNode,
                  autofocus: autofocus,
                  enabled: !isTextFieldDisabled,
                  minLines: 1,
                  maxLines: 4,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
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
