import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_env_config/flutter_env_config.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:stylens_app/core/managers/global_loader/index.dart';
import 'package:stylens_app/models/remote_image.dart';
import 'profile_menu.dart';
import 'dart:io';
import 'style_analysis.dart';

class CapturePage extends StatefulWidget {
  @override
  State<CapturePage> createState() => _CapturePageState();
}

class _CapturePageState extends State<CapturePage> {
  final ImagePicker _picker = ImagePicker();

  EnvironmentConfig config = EnvironmentManager.environmentData;

  Future<void> _navigateToStyleAnalysis(File imageFile, String filename) async {
    final RemoteImage? remoteImage = await _uploadToR2(imageFile, filename);
    print(remoteImage?.url);

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
  }

  Future<RemoteImage?> _uploadToR2(File imageFile, String filename) async {
    GlobalLoaderController.instance.show('Analyzing outfit');
    try {
      final presignedUrlRes = await http.get(
        Uri.parse(
          "${config.api?.baseUrl}/assets/upload-url?filename=$filename",
        ),
        headers: {"Content-Type": "application/json"},
      );

      if (presignedUrlRes.statusCode != 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Unable to upload outfit image.')),
          );
        }
        throw Exception("Failed to get upload URL");
      }

      final responseData = json.decode(presignedUrlRes.body);
      final uploadUrl = responseData['uploadUrl'];
      final downloadUrl = responseData['downloadUrl'];
      final returnedFilename = responseData['filename'];

      print('Upload URL: $uploadUrl');
      print('Download URL: $downloadUrl');
      print('Filename: $returnedFilename');

      final imageFileBytes = await imageFile.readAsBytes();
      final uploadImageResp = await http.put(
        Uri.parse(uploadUrl),
        body: imageFileBytes,
      );

      if (uploadImageResp.statusCode == 200) {
        print('✅ Uploaded successfully: ${uploadImageResp.statusCode}');
        return RemoteImage(url: downloadUrl, key: returnedFilename);
      } else {
        print(
          '❌ Upload failed: ${uploadImageResp.statusCode} ${uploadImageResp.body}',
        );
        return null;
      }
    } finally {
      GlobalLoaderController.instance.hide();
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 85,
      );

      if (photo != null) {
        _navigateToStyleAnalysis(File(photo.path), photo.name);
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
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 85,
      );

      if (image != null) {
        _navigateToStyleAnalysis(File(image.path), image.name);
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
    return Stack(
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
                    Text(
                      'GoStylens',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'ClashDisplay',
                            // fontSize: 20,
                          ),
                    ),
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
                      iconSize: 36,
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
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 16),
                        Text(
                          "Let's see how your outfit fits the vibe and I'll drop a few tips to make it even more you.",
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.9),
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
    );
  }
}
