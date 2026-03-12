import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gostylens/core/managers/style_analysis_session/index.dart';
import 'package:gostylens/models/style_analysis_session.dart';

class SessionActionsMenu extends StatelessWidget {
  final StyleAnalysisSession session;
  final VoidCallback? onDelete;
  final Color? iconColor;
  final double iconSize;
  final PopupMenuPosition position;
  final Key? popupKey;

  const SessionActionsMenu({
    super.key,
    required this.session,
    this.onDelete,
    this.iconColor,
    this.iconSize = 20,
    this.position = PopupMenuPosition.over,
    this.popupKey,
  });

  @override
  Widget build(BuildContext context) {
    final sessionManager = context.read<StyleAnalysisSessionManager>();

    return PopupMenuButton<String>(
      key: popupKey,
      position: position,
      icon: Icon(Icons.more_vert, size: iconSize, color: iconColor),
      onSelected: (value) {
        if (value == 'favorite') {
          sessionManager.toggleFavorite(
            session.id,
            !session.isFavorite,
            onError: (error) => _showErrorSnackBar(context, error),
          );
        } else if (value == 'rename') {
          _showRenameDialog(context, session, sessionManager);
        } else if (value == 'delete') {
          onDelete?.call();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'favorite',
          child: Row(
            children: [
              Icon(
                session.isFavorite ? Icons.favorite : Icons.favorite_border,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Text(
                session.isFavorite
                    ? 'Remove from favorites'
                    : 'Add to favorites',
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'rename',
          child: Row(
            children: [
              Icon(
                Icons.edit_outlined,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              SizedBox(width: 12),
              Text(
                'Rename',
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            ],
          ),
        ),
        if (onDelete != null)
          const PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete_outline, size: 18, color: Colors.red),
                SizedBox(width: 12),
                Text('Delete', style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
      ],
    );
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showRenameDialog(
    BuildContext context,
    StyleAnalysisSession session,
    StyleAnalysisSessionManager sessionManager,
  ) {
    final controller = TextEditingController(text: session.title);

    // Delay to let the PopupMenu fully dismiss before opening the dialog
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          insetPadding: EdgeInsets.symmetric(horizontal: 24),
          actionsPadding: const EdgeInsets.only(right: 16, bottom: 8, top: 0),
          backgroundColor: Theme.of(context).colorScheme.tertiary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Rename Session',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
              fontSize: 18,
            ),
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width,
            child: TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Enter new name',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
              child: Text(
                'Rename',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ).then((newName) {
        if (newName != null && newName.isNotEmpty && newName != session.title) {
          sessionManager.renameSession(
            session.id,
            newName,
            onError: (error) => _showErrorSnackBar(context, error),
          );
        }
      });
    });
  }
}
