import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:gostylens/core/config/dependency_injection.dart';
import 'package:gostylens/core/managers/intro_walkthrough_store.dart';
import 'package:gostylens/core/services/analytics_service.dart';
import 'package:gostylens/navigation/app_routes.dart';
import 'package:gostylens/pages/intro/chat_slide.dart';
import 'package:gostylens/pages/intro/features_slide.dart';
import 'package:gostylens/pages/intro/intro_colors.dart';
import 'package:gostylens/pages/intro/outfit_slide.dart';
import 'package:gostylens/widgets/page_pill_indicator.dart';

const _slideCount = 3;

/// Swipeable first-install product intro shown before login.
class IntroWalkthroughPage extends StatefulWidget {
  const IntroWalkthroughPage({super.key});

  @override
  State<IntroWalkthroughPage> createState() => _IntroWalkthroughPageState();
}

class _IntroWalkthroughPageState extends State<IntroWalkthroughPage> {
  final _controller = PageController();
  int _index = 0;
  double _page = 0;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
    locator<AnalyticsService>().capture('intro_started');
    locator<AnalyticsService>().capture(
      'intro_slide_viewed',
      properties: {'slide_index': 0},
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_controller.hasClients) return;
    final page = _controller.page ?? _index.toDouble();
    if ((page - _page).abs() < 0.01) return;
    setState(() => _page = page);
  }

  /// Start slide entrances a bit before the page fully settles so Next /
  /// swipe doesn't flash empty content, then pop in.
  bool _slideActive(int index) {
    final page = _controller.hasClients
        ? (_controller.page ?? _index.toDouble())
        : _index.toDouble();
    return (page - index).abs() < 0.72;
  }

  Future<void> _finish({required bool skipped}) async {
    if (_finishing) return;
    setState(() => _finishing = true);

    final analytics = locator<AnalyticsService>();
    if (skipped) {
      await analytics.capture(
        'intro_skipped',
        properties: {'slide_index': _index},
      );
    } else {
      await analytics.capture('intro_completed');
    }
    await locator<IntroWalkthroughStore>().markCompleted();
    if (!mounted) return;
    context.go(AppRoutes.login);
  }

  void _onPageChanged(int index) {
    setState(() => _index = index);
    locator<AnalyticsService>().capture(
      'intro_slide_viewed',
      properties: {'slide_index': index},
    );
  }

  void _onPrimary() {
    if (_finishing) return;
    if (_index < _slideCount - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 480),
        curve: Curves.easeInOutCubic,
      );
      return;
    }
    _finish(skipped: false);
  }

  String get _primaryLabel =>
      _index < _slideCount - 1 ? 'Next' : 'Start styling';

  bool get _isDarkSlide => _index == 0;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final bg = _isDarkSlide ? primary : IntroColors.cream;
    final pillActive = _isDarkSlide ? Colors.white : IntroColors.forest;
    final pillInactive = _isDarkSlide
        ? Colors.white.withValues(alpha: 0.28)
        : IntroColors.sage.withValues(alpha: 0.55);
    final buttonBg = _isDarkSlide ? Colors.white : IntroColors.forest;
    final buttonFg = _isDarkSlide ? primary : Colors.white;
    final skipColor = _isDarkSlide
        ? Colors.white.withValues(alpha: 0.55)
        : IntroColors.muted;

    // Dark slide → light icons; cream slides → dark icons (status + nav bar).
    final overlay = _isDarkSlide
        ? SystemUiOverlayStyle.light.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: primary,
            systemNavigationBarIconBrightness: Brightness.light,
          )
        : SystemUiOverlayStyle.dark.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: IntroColors.cream,
            systemNavigationBarIconBrightness: Brightness.dark,
          );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _finish(skipped: true);
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: overlay,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          color: bg,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: PageView(
                      controller: _controller,
                      onPageChanged: _onPageChanged,
                      children: [
                        IntroOutfitSlide(active: _slideActive(0)),
                        IntroChatSlide(active: _slideActive(1)),
                        IntroFeaturesSlide(active: _slideActive(2)),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 8, 28, 6),
                    child: Column(
                      children: [
                        PagePillIndicator(
                          count: _slideCount,
                          index: _index,
                          activeColor: pillActive,
                          inactiveColor: pillInactive,
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _finishing ? null : _onPrimary,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: buttonBg,
                              foregroundColor: buttonFg,
                              disabledBackgroundColor: buttonBg,
                              disabledForegroundColor: buttonFg,
                              elevation: _isDarkSlide ? 0 : 2,
                              shadowColor: Colors.black26,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              textStyle: const TextStyle(
                                fontFamily: 'Metropolis',
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            child: Text(_primaryLabel),
                          ),
                        ),
                        // Fixed height so hiding Skip on the last slide
                        // does not shift the footer / page content.
                        SizedBox(
                          height: 40,
                          child: _index < _slideCount - 1
                              ? TextButton(
                                  onPressed: _finishing
                                      ? null
                                      : () => _finish(skipped: true),
                                  style: TextButton.styleFrom(
                                    foregroundColor: skipColor,
                                    minimumSize: const Size(0, 40),
                                    padding: EdgeInsets.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    textStyle: const TextStyle(
                                      fontFamily: 'Metropolis',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  child: const Text('Skip intro'),
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
