import 'package:flutter/material.dart';

class StartConversationFab extends StatelessWidget {
  final VoidCallback onPressed;

  const StartConversationFab({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: onPressed,
      backgroundColor: Theme.of(context).colorScheme.primary,
      foregroundColor: Theme.of(context).colorScheme.onPrimary,
      shape: const CircleBorder(),
      child: const Icon(Icons.add_comment_outlined, size: 24),
    );
  }
}
