import 'package:flutter/material.dart';
import 'dart:io';
import 'package:gostylens/widgets/image_with_fallback.dart';
import 'package:gostylens/models/remote_image.dart';

class FullScreenImagePreview extends StatelessWidget {
  final File? imageFile;
  final String? imageUrl;
  final VoidCallback? onClose;

  const FullScreenImagePreview({
    super.key,
    this.imageFile,
    this.imageUrl,
    this.onClose,
  }) : assert(
         imageFile != null || imageUrl != null,
         'Either imageFile or imageUrl must be provided',
       );

  static Future<void> show(
    BuildContext context, {
    File? imageFile,
    String? imageUrl,
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      builder: (context) => FullScreenImagePreview(
        imageFile: imageFile,
        imageUrl: imageUrl,
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
              remoteImage:
                  imageUrl != null ? RemoteImage(url: imageUrl!, key: '') : null,
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
