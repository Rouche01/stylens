import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:gostylens/core/config/dependency_injection.dart';
import 'package:gostylens/core/services/api_service/index.dart';
import 'package:gostylens/models/remote_image.dart';
import 'package:gostylens/models/app_image.dart';

enum AssetUploadStatus { pending, uploading, success, failure }

class AssetUploadTask {
  final File file;
  final String filename;
  final RemoteImage remoteImage;
  final String? uploadUrl;
  AssetUploadStatus status;
  double progress;
  String? error;

  AssetUploadTask({
    required this.file,
    required this.filename,
    required this.remoteImage,
    this.uploadUrl,
    this.status = AssetUploadStatus.pending,
    this.progress = 0.0,
    this.error,
  });
}

class AssetUploadManager extends ChangeNotifier {
  final AssetApiService _assetApiService = locator<AssetApiService>();
  final Map<String, AssetUploadTask> _tasks = {};

  List<AssetUploadTask> get tasks => _tasks.values.toList();

  AssetUploadStatus? getStatus(String key) =>
      _tasks[key]?.status;

  AssetUploadTask? getTask(String key) => _tasks[key];

  /// Ensures all images in the list have remote target metadata (RemoteImage).
  /// Prepares assets and starts background uploads for any missing metadata.
  Future<List<AppImage>> ensureAssetsPrepared(List<AppImage> images) async {
    final imagesToPrepare =
        images.where((img) => img.remoteImage == null).toList();
    final filesToPrepare =
        imagesToPrepare.map((i) => i.localFile).whereType<File>().toList();

    List<RemoteImage> newlyPrepared = [];
    if (filesToPrepare.isNotEmpty) {
      newlyPrepared = await Future.wait<RemoteImage>(
        filesToPrepare.map((file) => prepareAsset(file)),
      );

      // Start background uploads for ONLY the newly prepared assets
      uploadAssets(newlyPrepared.map((ri) => ri.key).toList());
    }

    // Map all images to their complete AppImage versions
    return images.map((img) {
      if (img.remoteImage != null) return img; // Already prepared
      final file = img.localFile;
      if (file == null) return img;

      final index = filesToPrepare.indexOf(file);
      if (index != -1 && index < newlyPrepared.length) {
        return AppImage(localFile: file, remoteImage: newlyPrepared[index]);
      }
      return img;
    }).toList();
  }

  /// Reserves a RemoteImage object instantly (Fast JSON request).
  /// Doesn't start the binary upload yet.
  Future<RemoteImage> prepareAsset(File file) async {
    final filename =
        'style_analysis_${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';

    final responseData = await _assetApiService.getUploadUrl(filename);

    final remoteImage = RemoteImage(
      url: responseData.downloadUrl,
      key: responseData.filename,
    );

    final task = AssetUploadTask(
      file: file,
      filename: filename,
      remoteImage: remoteImage,
      uploadUrl: responseData.uploadUrl,
    );

    _tasks[remoteImage.key] = task;

    notifyListeners();
    return remoteImage;
  }

  /// Starts the binary uploads for the given keys in parallel.
  void uploadAssets(List<String> keys) {
    for (final key in keys) {
      final task = _tasks[key];
      if (task != null && task.status == AssetUploadStatus.pending) {
        final uploadUrl = task.uploadUrl;
        if (uploadUrl != null) {
          _performUpload(task, uploadUrl);
        }
      }
    }
  }

  Future<void> _performUpload(AssetUploadTask task, String uploadUrl) async {
    try {
      task.status = AssetUploadStatus.uploading;
      notifyListeners();

      final bytes = await task.file.readAsBytes();
      final statusCode = await _assetApiService.uploadImage(uploadUrl, bytes);

      if (statusCode == 200) {
        task.status = AssetUploadStatus.success;
        task.progress = 1.0;
      } else {
        task.status = AssetUploadStatus.failure;
        task.error = 'Upload failed with status: $statusCode';
      }
    } catch (e) {
      task.status = AssetUploadStatus.failure;
      task.error = e.toString();
      debugPrint('Background upload error: $e');
    } finally {
      notifyListeners();
    }
  }

  void retryUpload(String key, String uploadUrl) {
    final task = _tasks[key];
    if (task != null && task.status == AssetUploadStatus.failure) {
      _performUpload(task, uploadUrl);
    }
  }

  void clearCompletedTasks() {
    _tasks.removeWhere((_, task) => task.status == AssetUploadStatus.success);
    notifyListeners();
  }
}
