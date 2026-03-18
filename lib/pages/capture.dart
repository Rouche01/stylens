import 'package:flutter/material.dart';
import 'package:gostylens/constants/ux_messages.dart';
import 'package:image_picker/image_picker.dart';
import 'package:gostylens/core/managers/global_loader/index.dart';
import 'package:gostylens/models/remote_image.dart';
import 'package:gostylens/core/managers/subscription_manager.dart';
import 'package:gostylens/core/services/api_service/index.dart';
import 'package:gostylens/pages/paywall.dart';
import 'package:provider/provider.dart';
import 'profile_menu.dart';
import 'dart:io';
import 'style_analysis.dart';

class CapturePage extends StatefulWidget {
  @override
  State<CapturePage> createState() => _CapturePageState();
}

class _CapturePageState extends State<CapturePage> {
  final ImagePicker _picker = ImagePicker();

  Future<void> _startStyleAnalysisSession(
    File imageFile,
    String filename,
  ) async {
    try {
      final RemoteImage? remoteImage = await _uploadToR2(imageFile, filename);

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StyleAnalysisPage(
              outfitImageFile: imageFile,
              remoteImage: remoteImage,
            ),
          ),
        );
      }
    } catch (err) {
      print('$err');
    } finally {
      GlobalLoaderController.instance.hide();
    }
  }

  Future<RemoteImage?> _uploadToR2(File imageFile, String filename) async {
    GlobalLoaderController.instance.show(UxMessages.uploadOutfitLoader);
    try {
      final assetApiService = AssetApiService();
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
      GlobalLoaderController.instance.hide();
      rethrow;
    }
  }

  Future<bool> _checkLimitsAndProceed() async {
    final subManager = context.read<SubscriptionManager>();

    final sub = subManager.subscription;
    if (sub == null) {
      // Fallback: If for some reason we don't have subscription state yet
      // (e.g., fast app launch), fetch it quickly.
      GlobalLoaderController.instance.show('Your stylist is getting ready...');
      try {
        await subManager.syncSubscription();
      } finally {
        GlobalLoaderController.instance.hide();
      }
    }

    final isPro = subManager.userHasCorePlan;
    final activeSub = subManager.subscription;

    if (activeSub == null) return false;

    // Entitlement checks
    if (isPro || !activeSub.isFree || !activeSub.hasReachedLimit) {
      return true;
    }

    bool? result;

    // They've hit the limit. Show the paywall page.
    if (mounted) {
      result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (context) => const PaywallPage()),
      );
    }

    return result == true;
  }

  Future<void> _takePhoto() async {
    final canProceed = await _checkLimitsAndProceed();
    if (!canProceed) return;

    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 85,
      );

      if (photo != null) {
        _startStyleAnalysisSession(File(photo.path), photo.name);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error taking photo: $e')));
      }
    }
  }

  Future<void> _chooseFromGallery() async {
    final canProceed = await _checkLimitsAndProceed();
    if (!canProceed) return;

    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 85,
      );

      if (image != null) {
        _startStyleAnalysisSession(File(image.path), image.name);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error selecting image: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 0,
        backgroundColor: Theme.of(context).colorScheme.surfaceDim,
        elevation: 0,
      ),
      backgroundColor: Theme.of(context).colorScheme.surfaceDim,
      body: Stack(
        children: [
          Column(
            children: [
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    // vertical: 8.0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Image.asset('assets/imgs/logo_primary.png', height: 28),
                      IconButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ProfileMenuPage(),
                            ),
                          );
                        },
                        icon: Icon(Icons.account_circle),
                        iconSize: 39,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: 16.0,
                    right: 16.0,
                    top: 0,
                    bottom: 16.0,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.outline.withValues(alpha: 0.5),
                        width: 1,
                      ),
                      color: Theme.of(context).colorScheme.surfaceDim,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('📸', style: TextStyle(fontSize: 80)),
                          SizedBox(height: 24),
                          Text(
                            'Strike a Pose!',
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                  // fontWeight: FontWeight.bold,
                                  fontFamily: 'ClashDisplay',
                                  fontWeight: FontWeight.w500,
                                ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 16),
                          Text(
                            "Let's see how your outfit fits the vibe and I'll drop a few tips to make it even more you.",
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.9),
                                  height: 1.5,
                                ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 32),
                          ElevatedButton.icon(
                            onPressed: _takePhoto,
                            icon: Icon(Icons.photo_camera),
                            label: Text('Take Photo'),
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                              foregroundColor: Theme.of(
                                context,
                              ).colorScheme.onPrimary,
                            ),
                          ),
                          SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: _chooseFromGallery,
                            icon: Icon(Icons.photo_library),
                            label: Text('Choose from Gallery'),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
