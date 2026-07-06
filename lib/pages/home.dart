import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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

    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: NavigationBar(
            backgroundColor: Theme.of(
              context,
            ).navigationBarTheme.backgroundColor?.withValues(alpha: 0.8),
            selectedIndex: selectedIndex,
            onDestinationSelected: _onDestinationSelected,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.checkroom_outlined),
                selectedIcon: Icon(Icons.checkroom),
                label: 'Closet',
              ),
              NavigationDestination(
                icon: Icon(Icons.camera_alt_outlined),
                selectedIcon: Icon(Icons.camera_alt),
                label: 'Capture',
              ),
              NavigationDestination(
                icon: Icon(Icons.history_outlined),
                selectedIcon: Icon(Icons.history),
                label: 'History',
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: selectedIndex == _historyIndex
          ? StartConversationFab(
              onPressed: () => startNewSessionAndNavigate(context),
            )
          : null,
    );
  }
}
