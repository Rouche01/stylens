import 'package:flutter/material.dart';
import 'package:gostylens/widgets/floating_nav_bar.dart';
import 'package:gostylens/widgets/pose_video_backdrop.dart';

/// Capture tab hero card with video backdrop and action buttons.
///
/// Kept separate from [CapturePage] so header/subscription rebuilds do not
/// touch the video subtree.
class CaptureHeroCard extends StatelessWidget {
  const CaptureHeroCard({
    super.key,
    required this.onTakePhoto,
    required this.onChooseFromGallery,
  });

  final VoidCallback onTakePhoto;
  final VoidCallback onChooseFromGallery;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final scrim = Color.alphaBlend(
      Colors.black.withValues(alpha: 0.45),
      cs.primary,
    );

    return Padding(
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
                child: ColoredBox(color: scrim.withValues(alpha: 0.66)),
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
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
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
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const Spacer(flex: 2),
                    _CaptureActionBar(
                      onTakePhoto: onTakePhoto,
                      onChooseFromGallery: onChooseFromGallery,
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
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
