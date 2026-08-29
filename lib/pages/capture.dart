import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:gostylens/widgets/floating_nav_bar.dart';
import 'package:gostylens/widgets/pose_video_backdrop.dart';

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
    String filename, {
    required String source,
  }) async {
    try {
      // Step 1: Reserve the key (Fast JSON request)
      final remoteImage = await context.read<AssetUploadManager>().prepareAsset(
        imageFile,
      );

      if (mounted) {
        // Step 2: Start the binary upload in background (Parallel/Non-awaited)
        context.read<AssetUploadManager>().uploadAssets([remoteImage.key]);

        // Step 3: Prepare session sync, then navigate — intros play on-page.
        context.read<StyleAnalysisSessionManager>().prepareOutfitSession([
          AppImage(localFile: imageFile, remoteImage: remoteImage),
        ]);

        context.push(AppRoutes.sessionNew);

        // Step 4: Analytics
        locator<AnalyticsService>().capture(
          'image_capture_initiated',
          properties: {
            'filename': filename,
            'source': 'capture_page',
            'capture_source': source,
          },
        );
      }
    } catch (err, stackTrace) {
      debugPrint('Error starting session: $err');
      locator<AnalyticsService>().captureException(
        err,
        stackTrace: stackTrace,
        properties: {'context': 'image_prepare', 'source': source},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to prepare image. Please try again.')),
        );
      }
    }
  }

  Future<void> _takePhoto() async {
    final canProceed = await checkLimitsAndProceed(context, source: 'capture');
    if (!canProceed) return;

    locator<AnalyticsService>().capture(
      'capture_source_selected',
      properties: {'source': 'camera'},
    );

    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 85,
      );

      if (photo != null) {
        _startStyleAnalysisSession(
          File(photo.path),
          photo.name,
          source: 'camera',
        );
      }
    } catch (e, stackTrace) {
      locator<AnalyticsService>().captureException(
        e,
        stackTrace: stackTrace,
        properties: {'context': 'image_prepare', 'source': 'camera'},
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error taking photo: $e')));
      }
    }
  }

  Future<void> _chooseFromGallery() async {
    final canProceed = await checkLimitsAndProceed(context, source: 'capture');
    if (!canProceed) return;

    locator<AnalyticsService>().capture(
      'capture_source_selected',
      properties: {'source': 'gallery'},
    );

    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 85,
      );

      if (image != null) {
        _startStyleAnalysisSession(
          File(image.path),
          image.name,
          source: 'gallery',
        );
      }
    } catch (e, stackTrace) {
      locator<AnalyticsService>().captureException(
        e,
        stackTrace: stackTrace,
        properties: {'context': 'image_prepare', 'source': 'gallery'},
      );
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
    final scrim = Color.alphaBlend(
      Colors.black.withValues(alpha: 0.45),
      cs.primary,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: cs.surfaceDim,
        body: Column(
          children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
                child: Row(
                  children: [
                    Image.asset('assets/imgs/logo_primary.png', height: 28),
                    Consumer<SubscriptionManager>(
                      builder: (context, subManager, _) {
                        final subscription = subManager.subscription;
                        final showUpgrade =
                            !subManager.userHasCorePlan &&
                            subscription != null &&
                            !subscription.hasUnlimitedSessions;

                        if (!showUpgrade) return const SizedBox.shrink();

                        return Padding(
                          padding: const EdgeInsets.only(left: 10),
                          child: FilledButton(
                            onPressed: () {
                              context.push(AppRoutes.paywall);
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: cs.secondary.withValues(
                                alpha: 0.55,
                              ),
                              foregroundColor: cs.primary,
                              elevation: 0,
                              shadowColor: Colors.transparent,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: cs.primary.withValues(alpha: 0.35),
                                ),
                              ),
                            ),
                            child: const Text(
                              'Upgrade',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const Spacer(),
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
                  16 + FloatingNavBar.contentBottomInset(context),
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.28),
                      width: 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        const Positioned.fill(child: PoseVideoBackdrop()),
                        Positioned.fill(
                          child: ColoredBox(
                            color: scrim.withValues(alpha: 0.66),
                          ),
                        ),
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  scrim.withValues(alpha: 0.40),
                                ],
                                stops: const [0.48, 1.0],
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                          child: Column(
                            children: [
                              const Spacer(flex: 6),
                              Text(
                                'Strike a Pose!',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontFamily: 'ClashDisplay',
                                      fontWeight: FontWeight.w600,
                                      fontSize: 32,
                                      height: 1.15,
                                      letterSpacing: -0.4,
                                    ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                "Share your outfit. I’ll tell you what works, and what to try next.",
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.9,
                                      ),
                                      height: 1.5,
                                    ),
                                textAlign: TextAlign.center,
                              ),
                              const Spacer(flex: 2),
                              _CaptureActionBar(
                                onTakePhoto: _takePhoto,
                                onChooseFromGallery: _chooseFromGallery,
                              ),
                              const SizedBox(height: 8),
                            ],
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
      ),
    );
  }
}

class _CaptureActionBar extends StatelessWidget {
  const _CaptureActionBar({
    required this.onTakePhoto,
    required this.onChooseFromGallery,
  });

  final VoidCallback onTakePhoto;
  final VoidCallback onChooseFromGallery;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: onTakePhoto,
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.secondary,
                foregroundColor: cs.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.camera_alt_outlined, color: cs.primary, size: 18),
                  const SizedBox(width: 8),
                  const Text('Take Photo'),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: onChooseFromGallery,
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          child: const Text('Choose from gallery'),
        ),
      ],
    );
  }
}
