import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gostylens/core/managers/asset_upload_manager.dart';

class UploadStatusIndicator extends StatefulWidget {
  final String assetKey;

  const UploadStatusIndicator({super.key, required this.assetKey});

  @override
  State<UploadStatusIndicator> createState() => _UploadStatusIndicatorState();
}

class _UploadStatusIndicatorState extends State<UploadStatusIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  bool _isVisible = true;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) return const SizedBox.shrink();

    return Consumer<AssetUploadManager>(
      builder: (context, manager, child) {
        final status = manager.getStatus(widget.assetKey);

        if (status == null) return const SizedBox.shrink();

        if (status == AssetUploadStatus.success) {
          // Trigger the fade out after a brief checkmark display
          Future.delayed(const Duration(milliseconds: 1500), () {
            if (mounted && _isVisible) {
              _fadeController.forward().then((_) {
                setState(() => _isVisible = false);
              });
            }
          });
        }

        return FadeTransition(
          opacity: ReverseAnimation(_fadeAnimation),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: _buildIconForStatus(status),
          ),
        );
      },
    );
  }

  Widget _buildIconForStatus(AssetUploadStatus status) {
    switch (status) {
      case AssetUploadStatus.pending:
      case AssetUploadStatus.uploading:
        return const SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        );
      case AssetUploadStatus.success:
        return const Icon(Icons.check, size: 12, color: Colors.white);
      case AssetUploadStatus.failure:
        return const Icon(
          Icons.priority_high,
          size: 12,
          color: Colors.redAccent,
        );
    }
  }
}
