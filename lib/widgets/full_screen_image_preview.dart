import 'package:flutter/material.dart';
import 'dart:io';
import 'package:gostylens/widgets/image_with_fallback.dart';
import 'package:gostylens/models/remote_image.dart';

class FullScreenImagePreview extends StatelessWidget {
  final File? imageFile;
  final RemoteImage? remoteImage;
  final VoidCallback? onClose;

  const FullScreenImagePreview({
    super.key,
    this.imageFile,
    this.remoteImage,
    this.onClose,
  }) : assert(
         imageFile != null || remoteImage != null,
         'Either imageFile or remoteImage must be provided',
       );

  static Future<void> show(
    BuildContext context, {
    File? imageFile,
    RemoteImage? remoteImage,
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      builder: (context) => FullScreenImagePreview(
        imageFile: imageFile,
        remoteImage: remoteImage,
        onClose: () => Navigator.pop(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Center(
          child: InteractiveViewer(
            child: ImageWithFallback(
              imageFile: imageFile,
              remoteImage: remoteImage,
              fit: BoxFit.contain,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
        ),
        Positioned(
          top: 40,
          right: 20,
          child: Material(
            color: Colors.transparent,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: onClose ?? () => Navigator.pop(context),
            ),
          ),
        ),
      ],
    );
  }
}
