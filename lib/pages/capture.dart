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
import 'package:gostylens/widgets/capture_hero_card.dart';
import 'package:gostylens/widgets/capture_page_header.dart';

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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surfaceDim,
        body: Column(
          children: [
            const CapturePageHeader(),
            Expanded(
              child: CaptureHeroCard(
                onTakePhoto: _takePhoto,
                onChooseFromGallery: _chooseFromGallery,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
