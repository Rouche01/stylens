import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gostylens/widgets/primary_button.dart';
import 'package:gostylens/widgets/custom_form_field.dart';
import 'dart:math' as math;
import 'dart:ui';

class ClosetPage extends StatefulWidget {
  const ClosetPage({super.key});

  @override
  State<ClosetPage> createState() => _ClosetPageState();
}

class _ClosetPageState extends State<ClosetPage> with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _pulseController;
  final TextEditingController _emailController = TextEditingController();

  final List<IconData> _clothingIcons = [
    FontAwesomeIcons.shirt,
    FontAwesomeIcons.userTie,
    FontAwesomeIcons.vest,
    FontAwesomeIcons.hatCowboy,
    FontAwesomeIcons.socks,
    FontAwesomeIcons.shoePrints,
    FontAwesomeIcons.mitten,
    FontAwesomeIcons.glasses,
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat(reverse: true);

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    _pulseController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surfaceDim,
      body: Stack(
        children: [
          // Animated Background Grid
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return CustomPaint(
                  painter: _ClosetBackgroundPainter(
                    animationValue: _controller.value,
                    icons: _clothingIcons,
                    color: cs.primary.withValues(alpha: 0.05),
                  ),
                );
              },
            ),
          ),

          // Main Content Card
          Align(
            alignment: Alignment.bottomCenter,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 16,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 450),
                      padding: const EdgeInsets.all(0),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(40),
                        border: Border.all(
                          color: cs.secondary.withValues(alpha: 0.7),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: cs.primary.withValues(alpha: 0.15),
                            blurRadius: 40,
                            offset: const Offset(0, -10),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 24),
                          // Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: cs.secondary.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                FadeTransition(
                                  opacity: Tween<double>(
                                    begin: 0.3,
                                    end: 1.0,
                                  ).animate(_pulseController),
                                  child: ScaleTransition(
                                    scale: Tween<double>(
                                      begin: 0.6,
                                      end: 1.2,
                                    ).animate(_pulseController),
                                    child: Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: cs.secondaryFixedDim,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'COMING SOON',
                                  style: TextStyle(
                                    color: cs.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Title
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24.0,
                            ),
                            child: Text(
                              'Your closet,\nalways with you.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'ClashDisplay',
                                fontSize: 32,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.9),
                                letterSpacing: -0.2,
                                height: 1.1,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Subtitle
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              'Every outfit you analyse gets saved here — tagged, organised, and ready to mix & match.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Metropolis',
                                fontSize: 15,
                                color: cs.tertiary.withValues(alpha: 0.9),
                                height: 1.4,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Features
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _FeatureChip(
                                label: 'Auto-extract items',
                                icon: Icons.auto_awesome,
                                color: cs.primary,
                                textColor: cs.secondary.withValues(alpha: 0.9),
                              ),
                              _FeatureChip(
                                label: 'Mix & match',
                                icon: Icons.shuffle,
                                color: cs.primary,
                                textColor: cs.secondary.withValues(alpha: 0.9),
                              ),
                              _FeatureChip(
                                label: 'Unlimited storage',
                                icon: Icons.inventory_2,
                                color: cs.primary,
                                textColor: cs.secondary.withValues(alpha: 0.9),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),

                          // Email Capture
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24.0,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: CustomFormField(
                                    controller: _emailController,
                                    fieldType: FieldType.email,
                                    hintText: 'your@email.com',
                                    hintStyle: TextStyle(
                                      color: cs.secondary.withValues(
                                        alpha: 0.5,
                                      ),
                                      fontWeight: FontWeight.w500,
                                      fontSize: 15,
                                    ),
                                    textStyle: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 15,
                                    ),
                                    fillColor: cs.primary.withValues(
                                      alpha: 0.5,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(
                                        color: cs.secondary.withValues(
                                          alpha: 0.2,
                                        ),
                                        width: 1,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(
                                        color: cs.secondary.withValues(
                                          alpha: 0.8,
                                        ),
                                        width: 1,
                                      ),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                      horizontal: 16,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: PrimaryButton(
                                    label: 'Notify me',
                                    onPressed: () {
                                      // Logic for notification
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: cs.primary,
                                      foregroundColor: cs.secondary.withValues(
                                        alpha: 0.8,
                                      ),
                                      textStyle: TextStyle(
                                        fontFamily: 'Metropolis',
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        side: BorderSide(
                                          color: cs.primary,
                                          width: 1,
                                        ),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
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

class _FeatureChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color textColor;

  const _FeatureChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClosetBackgroundPainter extends CustomPainter {
  final double animationValue;
  final List<IconData> icons;
  final Color color;

  _ClosetBackgroundPainter({
    required this.animationValue,
    required this.icons,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double spacing = 130.0;
    final double tileSize = 110.0;
    final int rows = (size.height / spacing).ceil() + 1;
    final int cols = (size.width / spacing).ceil() + 1;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final iconIndex = (r * cols + c) % icons.length;
        final icon = icons[iconIndex];

        // Slight drift animation
        final double dx =
            c * spacing + (math.sin(animationValue * math.pi * 2 + r) * 15);
        final double dy =
            r * spacing + (math.cos(animationValue * math.pi * 2 + c) * 15);

        // Draw tile background
        final Rect tileRect = Rect.fromCenter(
          center: Offset(dx, dy),
          width: tileSize,
          height: tileSize,
        );
        final Paint tilePaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.8)
          ..style = PaintingStyle.fill;

        canvas.drawRRect(
          RRect.fromRectAndRadius(tileRect, const Radius.circular(20)),
          tilePaint,
        );

        // Draw Tile Border
        final Paint borderPaint = Paint()
          ..color = color.withValues(alpha: 0.1)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;

        canvas.drawRRect(
          RRect.fromRectAndRadius(tileRect, const Radius.circular(20)),
          borderPaint,
        );

        // Draw Icon
        final TextPainter textPainter = TextPainter(
          textDirection: TextDirection.ltr,
          text: TextSpan(
            text: String.fromCharCode(icon.codePoint),
            style: TextStyle(
              fontSize: 45,
              fontFamily: icon.fontFamily,
              package: icon.fontPackage,
              color: color.withValues(
                alpha: 0.2,
              ), // More visible but still subtle
            ),
          ),
        );

        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(dx - textPainter.width / 2, dy - textPainter.height / 2),
        );

        // Draw Lock Overlay
        final lockPainter = TextPainter(
          textDirection: TextDirection.ltr,
          text: TextSpan(
            text: String.fromCharCode(Icons.lock_rounded.codePoint),
            style: TextStyle(
              fontSize: 14,
              fontFamily: Icons.lock_rounded.fontFamily,
              package: Icons.lock_rounded.fontPackage,
              color: color.withValues(alpha: 0.4),
            ),
          ),
        );
        lockPainter.layout();
        lockPainter.paint(canvas, Offset(dx + 30, dy - 40));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ClosetBackgroundPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
