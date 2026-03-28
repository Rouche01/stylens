import 'dart:io';
import 'package:flutter/material.dart';
import 'package:gostylens/models/remote_image.dart';
import 'package:gostylens/widgets/image_with_fallback.dart';
import 'package:gostylens/widgets/full_screen_image_preview.dart';

class MessageImageGallery extends StatelessWidget {
  final List<File>? imageFiles;
  final List<RemoteImage>? remoteImages;

  const MessageImageGallery({
    super.key,
    this.imageFiles,
    this.remoteImages,
  });

  @override
  Widget build(BuildContext context) {
    final totalImages = (imageFiles?.length ?? 0) + (remoteImages?.length ?? 0);
    if (totalImages == 0) return const SizedBox.shrink();

    final isSingleImage = totalImages == 1;

    if (isSingleImage) {
      return GestureDetector(
        onTap: () => FullScreenImagePreview.show(
          context,
          imageFile: imageFiles?.isNotEmpty ?? false ? imageFiles!.first : null,
          imageUrl: remoteImages?.isNotEmpty ?? false ? remoteImages!.first.url : null,
        ),
        child: ImageWithFallback(
          imageFile: imageFiles?.isNotEmpty ?? false ? imageFiles!.first : null,
          remoteImage: remoteImages?.isNotEmpty ?? false ? remoteImages!.first : null,
          width: 200,
          height: 200,
          fit: BoxFit.cover,
          borderRadius: BorderRadius.circular(8),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (imageFiles != null)
          ...imageFiles!.map(
            (file) => GestureDetector(
              onTap: () => FullScreenImagePreview.show(
                context,
                imageFile: file,
              ),
              child: ImageWithFallback(
                imageFile: file,
                width: 100,
                height: 100,
                fit: BoxFit.cover,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        if (remoteImages != null)
          ...remoteImages!.map(
            (image) => GestureDetector(
              onTap: () => FullScreenImagePreview.show(
                context,
                imageUrl: image.url,
              ),
              child: ImageWithFallback(
                remoteImage: image,
                width: 100,
                height: 100,
                fit: BoxFit.cover,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
      ],
    );
  }
}
