import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gostylens/core/config/dependency_injection.dart';
import 'package:gostylens/core/services/pose_video_service.dart';
import 'package:gostylens/utils/style_analysis_actions.dart';
import 'package:gostylens/widgets/floating_nav_bar.dart';
import 'package:gostylens/widgets/satellite_action_button.dart';

/// Bottom-nav shell hosting the Closet / Capture / History tab branches.
///
/// Driven by GoRouter's [StatefulNavigationShell] so each tab keeps its own
/// navigation stack and state across switches.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with StyleAnalysisActions {
  static const int _captureIndex = 1;
  static const int _historyIndex = 2;

  @override
  void initState() {
    super.initState();
    unawaited(locator<PoseVideoService>().ensureInitialized());
  }

  Future<void> _onDestinationSelected(int index) async {
    final shell = widget.navigationShell;
    if (index == shell.currentIndex) {
      shell.goBranch(index, initialLocation: true);
      return;
    }

    final leavingCapture =
        shell.currentIndex == _captureIndex && index != _captureIndex;
    if (leavingCapture) {
      await locator<PoseVideoService>().setPlayback(shouldPlay: false);
    }

    if (!mounted) return;
    shell.goBranch(index);
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = widget.navigationShell.currentIndex;
    final dockBottom = FloatingNavBar.dockBottomInset(context);
    final showSatellite = selectedIndex == _historyIndex;
    // Only reserve for the full-width dock; the satellite is a corner overlay
    // so list content can scroll underneath it.
    final reservedBottom = FloatingNavBar.contentBottomInset(context);
    final media = MediaQuery.of(context);

    return Scaffold(
      extendBody: true,
      // Let tab scaffolds paint full-bleed under the dock; inject bottom padding
      // so SafeArea / MediaQuery consumers still clear the floating bar.
      body: Stack(
        children: [
          MediaQuery(
            data: media.copyWith(
              padding: media.padding.copyWith(bottom: reservedBottom),
            ),
            child: widget.navigationShell,
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, dockBottom),
              child: FloatingNavBar(
                selectedIndex: selectedIndex,
                onDestinationSelected: (index) {
                  unawaited(_onDestinationSelected(index));
                },
              ),
            ),
          ),
          Positioned(
            right: SatelliteActionButton.sideInset,
            bottom:
                dockBottom +
                FloatingNavBar.height +
                SatelliteActionButton.gapAboveDock,
            child: IgnorePointer(
              ignoring: !showSatellite,
              child: AnimatedScale(
                scale: showSatellite ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 240),
                curve: showSatellite
                    ? Curves.easeOutBack
                    : Curves.easeInCubic,
                child: AnimatedOpacity(
                  opacity: showSatellite ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  child: SatelliteActionButton(
                    onPressed: () => startNewSessionAndNavigate(context),
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
