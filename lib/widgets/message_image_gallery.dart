import 'dart:io';
import 'package:flutter/material.dart';
import 'package:gostylens/models/app_image.dart';
import 'package:gostylens/models/remote_image.dart';
import 'package:gostylens/widgets/image_with_fallback.dart';
import 'package:gostylens/widgets/full_screen_image_preview.dart';
import 'package:gostylens/widgets/upload_status_indicator.dart';

class MessageImageGallery extends StatelessWidget {
  final List<AppImage>? images;

  const MessageImageGallery({super.key, this.images});

  @override
  Widget build(BuildContext context) {
    if (images == null || images!.isEmpty) return const SizedBox.shrink();

    final int count = images!.length;
    final bool isSingle = count == 1;

    if (isSingle) {
      final img = images!.first;
      return _buildLargeImage(
        context,
        imageFile: img.localFile,
        remoteImage: img.remoteImage,
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: images!.map((img) {
        return _buildThumbnail(
          context,
          imageFile: img.localFile,
          remoteImage: img.remoteImage,
        );
      }).toList(),
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
          // Only show upload status for fresh uploads (active session)
          if (remoteImage != null && imageFile != null)
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
          // Only show upload status for fresh uploads (active session)
          if (remoteImage != null && imageFile != null)
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
