import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gostylens/widgets/floating_nav_bar.dart';
import 'package:gostylens/widgets/start_conversation_fab.dart';
import 'package:gostylens/utils/style_analysis_actions.dart';

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
  static const int _historyIndex = 2;

  void _onDestinationSelected(int index) {
    widget.navigationShell.goBranch(
      index,
      // Re-tapping the active tab returns it to its initial route.
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = widget.navigationShell.currentIndex;
    final dockBottom = FloatingNavBar.dockBottomInset(context);
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
                onDestinationSelected: _onDestinationSelected,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: selectedIndex == _historyIndex
          ? Padding(
              padding: EdgeInsets.only(bottom: reservedBottom),
              child: StartConversationFab(
                onPressed: () => startNewSessionAndNavigate(context),
              ),
            )
          : null,
    );
  }
}
