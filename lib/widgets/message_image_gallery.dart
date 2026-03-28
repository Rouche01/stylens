import 'dart:io';
import 'package:flutter/material.dart';
import 'package:gostylens/models/remote_image.dart';
import 'package:gostylens/widgets/image_with_fallback.dart';
import 'package:gostylens/widgets/full_screen_image_preview.dart';

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
        isUploading: true,
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: imageFiles!
          .map(
            (file) =>
                _buildThumbnail(context, imageFile: file, isUploading: true),
          )
          .toList(),
    );
  }

  Widget _buildLargeImage(
    BuildContext context, {
    File? imageFile,
    RemoteImage? remoteImage,
    bool isUploading = false,
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
          if (isUploading) _buildUploadingOverlay(200, 200),
        ],
      ),
    );
  }

  Widget _buildThumbnail(
    BuildContext context, {
    File? imageFile,
    RemoteImage? remoteImage,
    bool isUploading = false,
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
          if (isUploading) _buildUploadingOverlay(100, 100),
        ],
      ),
    );
  }

  Widget _buildUploadingOverlay(double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Uploading...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
