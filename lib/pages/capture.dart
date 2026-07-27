import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gostylens/core/config/dependency_injection.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import 'package:gostylens/core/managers/style_analysis_session/index.dart';
import 'package:gostylens/core/managers/subscription_manager.dart';
import 'package:gostylens/core/managers/asset_upload_manager.dart';
import 'package:gostylens/navigation/app_routes.dart';
import 'package:gostylens/utils/style_analysis_actions.dart';
import 'package:gostylens/core/services/analytics_service.dart';
import 'package:gostylens/models/app_image.dart';

class CapturePage extends StatefulWidget {
  const CapturePage({super.key});

  @override
  State<CapturePage> createState() => _CapturePageState();
}

class _CapturePageState extends State<CapturePage> with StyleAnalysisActions {
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SubscriptionManager>().syncSubscription();
    });
  }

  Future<void> _startStyleAnalysisSession(
    File imageFile,
    String filename,
  ) async {
    try {
      // Step 1: Reserve the key (Fast JSON request)
      final remoteImage = await context.read<AssetUploadManager>().prepareAsset(
        imageFile,
      );

      if (mounted) {
        // Step 2: Start the binary upload in background (Parallel/Non-awaited)
        context.read<AssetUploadManager>().uploadAssets([remoteImage.key]);

        // Step 3: Initialize the session with the metadata and local file
        context.read<StyleAnalysisSessionManager>().startSessionWithOutfit([
          AppImage(localFile: imageFile, remoteImage: remoteImage),
        ]);

        // Step 3: Navigate instantly
        context.push(AppRoutes.sessionNew);

        // Step 4: Analytics
        locator<AnalyticsService>().capture(
          'image_capture_initiated',
          properties: {'filename': filename, 'source': 'capture_page'},
        );
      }
    } catch (err) {
      debugPrint('Error starting session: $err');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to prepare image. Please try again.')),
        );
      }
    }
  }

  Future<void> _takePhoto() async {
    final canProceed = await checkLimitsAndProceed(context);
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
    final canProceed = await checkLimitsAndProceed(context);
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
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surfaceDim,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Image.asset('assets/imgs/logo_primary.png', height: 28),
                  IconButton(
                    onPressed: () {
                      context.push(AppRoutes.profile);
                    },
                    icon: const Icon(Icons.account_circle_rounded),
                    iconSize: 39,
                    color: cs.primary,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Padding(
              // Clear the floating dock while the Scaffold background extends under it.
              padding: EdgeInsets.fromLTRB(
                16,
                0,
                16,
                16 + MediaQuery.paddingOf(context).bottom,
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: cs.outline.withValues(alpha: 0.5),
                    width: 1,
                  ),
                  color: cs.surfaceDim,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('📸', style: TextStyle(fontSize: 80)),
                      const SizedBox(height: 24),
                      Text(
                        'Strike a Pose!',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: cs.onSurface,
                              fontFamily: 'ClashDisplay',
                              fontWeight: FontWeight.w500,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Let's see how your outfit fits the vibe and I'll drop a few tips to make it even more you.",
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.9),
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton.icon(
                        onPressed: _takePhoto,
                        icon: const Icon(Icons.photo_camera),
                        label: const Text('Take Photo'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          backgroundColor: cs.primary,
                          foregroundColor: cs.onPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _chooseFromGallery,
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Choose from Gallery'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
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
    );
  }
}
