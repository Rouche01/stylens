import 'dart:io';
import 'package:flutter/material.dart';
import 'package:gostylens/core/managers/global_loader/index.dart';
import 'package:gostylens/core/managers/subscription_manager.dart';
import 'package:gostylens/core/config/dependency_injection.dart';
import 'package:gostylens/core/services/api_service/index.dart';
import 'package:gostylens/models/remote_image.dart';
import 'package:gostylens/pages/paywall.dart';
import 'package:provider/provider.dart';

mixin StyleAnalysisActions {
  /// Checks if the user has reached their free tier limit and shows paywall if needed.
  Future<bool> checkLimitsAndProceed(BuildContext context) async {
    final subManager = context.read<SubscriptionManager>();

    if (subManager.subscription == null) {
      locator<GlobalLoaderController>().show('Your stylist is getting ready...');
      try {
        await subManager.syncSubscription();
      } finally {
        locator<GlobalLoaderController>().hide();
      }
    }

    final activeSub = subManager.subscription;

    if (activeSub == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to verify your plan. Please try again.'),
          ),
        );
      }
      return false;
    }

    if (!activeSub.isFree || !activeSub.hasReachedLimit) {
      return true;
    }

    if (!context.mounted) return false;

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const PaywallPage()),
    );

    return result == true;
  }

  /// Uploads an image to R2 and returns the RemoteImage object.
  Future<RemoteImage?> uploadToR2(File imageFile, String filename) async {
    try {
      final assetApiService = locator<AssetApiService>();
      final responseData = await assetApiService.getUploadUrl(filename);

      final uploadUrl = responseData.uploadUrl;
      final downloadUrl = responseData.downloadUrl;
      final returnedFilename = responseData.filename;

      final imageFileBytes = await imageFile.readAsBytes();
      final statusCode = await assetApiService.uploadImage(
        uploadUrl,
        imageFileBytes,
      );

      if (statusCode == 200) {
        return RemoteImage(url: downloadUrl, key: returnedFilename);
      } else {
        debugPrint('❌ Upload failed: $statusCode');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Upload error: $e');
      return null;
    }
  }
}
