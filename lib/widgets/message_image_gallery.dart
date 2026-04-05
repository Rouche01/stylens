import 'dart:io';
import 'package:flutter/material.dart';
import 'package:gostylens/models/remote_image.dart';
import 'package:gostylens/widgets/image_with_fallback.dart';
import 'package:gostylens/widgets/full_screen_image_preview.dart';
import 'package:gostylens/widgets/upload_status_indicator.dart';

class MessageImageGallery extends StatelessWidget {
  final List<File>? imageFiles;
  final List<RemoteImage>? remoteImages;

  const MessageImageGallery({super.key, this.imageFiles, this.remoteImages});

  @override
  Widget build(BuildContext context) {
    final remoteCount = remoteImages?.length ?? 0;
    final localCount = imageFiles?.length ?? 0;

    if (remoteCount == 0 && localCount == 0) return const SizedBox.shrink();

    // Use remoteImages as the source of truth if available, 
    // otherwise fallback to imageFiles (e.g. while preparing).
    final int count = remoteCount > 0 ? remoteCount : localCount;
    final bool isSingle = count == 1;

    if (isSingle) {
      return _buildLargeImage(
        context,
        imageFile: localCount > 0 ? imageFiles!.first : null,
        remoteImage: remoteCount > 0 ? remoteImages!.first : null,
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(count, (index) {
        return _buildThumbnail(
          context,
          imageFile: index < localCount ? imageFiles![index] : null,
          remoteImage: index < remoteCount ? remoteImages![index] : null,
        );
      }),
    );
  }

  Widget _buildLargeImage(
    BuildContext context, {
    File? imageFile,
    RemoteImage? remoteImage,
  }) {
    return GestureDetector(
      onTap: () => FullScreenImagePreview.show(
        context,
        imageFile: imageFile,
        imageUrl: remoteImage?.url,
      ),
      child: Stack(
        children: [
          ImageWithFallback(
            imageFile: imageFile,
            remoteImage: remoteImage,
            width: 200,
            height: 200,
            fit: BoxFit.cover,
            borderRadius: BorderRadius.circular(8),
          ),
          if (remoteImage != null)
            Positioned(
              bottom: 6,
              right: 6,
              child: UploadStatusIndicator(assetKey: remoteImage.key),
            ),
        ],
      ),
    );
  }

  Widget _buildThumbnail(
    BuildContext context, {
    File? imageFile,
    RemoteImage? remoteImage,
  }) {
    return GestureDetector(
      onTap: () => FullScreenImagePreview.show(
        context,
        imageFile: imageFile,
        imageUrl: remoteImage?.url,
      ),
      child: Stack(
        children: [
          ImageWithFallback(
            imageFile: imageFile,
            remoteImage: remoteImage,
            width: 100,
            height: 100,
            fit: BoxFit.cover,
            borderRadius: BorderRadius.circular(8),
          ),
          if (remoteImage != null)
            Positioned(
              bottom: 4,
              right: 4,
              child: UploadStatusIndicator(assetKey: remoteImage.key),
            ),
        ],
      ),
    );
  }
}
