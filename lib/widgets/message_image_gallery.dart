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
    final hasLocal = imageFiles?.isNotEmpty ?? false;
    final hasRemote = remoteImages?.isNotEmpty ?? false;

    if (!hasLocal && !hasRemote) return const SizedBox.shrink();

    // If we have both, we prioritze showing remote images if they are likely the same.
    // However, for the "Instant Send" flow, we'll have local files first, then remote images added.
    // To keep it simple: if remoteImages is not empty, we show those.
    // If only localFiles is not empty, we show those with an "Uploading" overlay.

    if (hasRemote) {
      final isSingle = remoteImages!.length == 1;
      if (isSingle) {
        return _buildLargeImage(context, remoteImage: remoteImages!.first);
      }
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: remoteImages!
            .map((img) => _buildThumbnail(context, remoteImage: img))
            .toList(),
      );
    }

    // Local only case (Uploading state)
    final isSingleLocal = imageFiles!.length == 1;
    if (isSingleLocal) {
      return _buildLargeImage(
        context,
        imageFile: imageFiles!.first,
        // For local files without remote counterpart yet, we'd need a way to track them.
        // But in our current flow, prepareAsset is called BEFORE navigation,
        // so we should have remoteImages available or arriving soon.
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: imageFiles!
          .map((file) => _buildThumbnail(context, imageFile: file))
          .toList(),
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
