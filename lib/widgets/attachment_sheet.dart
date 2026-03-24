import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class AttachmentSheet extends StatelessWidget {
  final Function(ImageSource source) onSourceSelected;

  const AttachmentSheet({super.key, required this.onSourceSelected});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: MediaQuery.of(context).size.height / 3,
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          ListTile(
            leading: Icon(Icons.photo_camera, color: colorScheme.primary),
            title: Text(
              'Take Photo',
              style: TextStyle(color: colorScheme.primary),
            ),
            onTap: () {
              Navigator.pop(context);
              onSourceSelected(ImageSource.camera);
            },
          ),
          ListTile(
            leading: Icon(Icons.photo_library, color: colorScheme.primary),
            title: Text(
              'Choose from Gallery',
              style: TextStyle(color: colorScheme.primary),
            ),
            onTap: () {
              Navigator.pop(context);
              onSourceSelected(ImageSource.gallery);
            },
          ),
        ],
      ),
    );
  }

  /// Helper to show the sheet with standard styling
  static void show(
    BuildContext context, {
    required Function(ImageSource source) onSourceSelected,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.tertiary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => AttachmentSheet(onSourceSelected: onSourceSelected),
    );
  }
}
