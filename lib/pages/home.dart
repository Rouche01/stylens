import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:gostylens/core/config/dependency_injection.dart';
import 'package:gostylens/core/navigation/home_tab_controller.dart';
import 'package:gostylens/pages/capture.dart';
import 'package:gostylens/pages/closet.dart';
import 'package:gostylens/pages/history.dart';
import 'package:gostylens/widgets/start_conversation_fab.dart';
import 'package:gostylens/utils/style_analysis_actions.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with StyleAnalysisActions {
  final HomeTabController _homeTabController = locator<HomeTabController>();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _homeTabController,
      builder: (context, _) {
        final selectedIndex = _homeTabController.tabIndex;

        Widget page;
        switch (selectedIndex) {
          case 0:
            page = ClosetPage();
          case 1:
            page = CapturePage();
          case 2:
            page = HistoryPage();
          default:
            throw UnimplementedError('no widget for $selectedIndex');
        }

        return Scaffold(
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            switchInCurve: Curves.easeInOut,
            switchOutCurve: Curves.easeInOut,
            child: Container(key: ValueKey<int>(selectedIndex), child: page),
          ),
          bottomNavigationBar: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: NavigationBar(
                backgroundColor: Theme.of(
                  context,
                ).navigationBarTheme.backgroundColor?.withValues(alpha: 0.8),
                selectedIndex: selectedIndex,
                onDestinationSelected: _homeTabController.setTab,
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
          floatingActionButton: selectedIndex == 2
              ? StartConversationFab(
                  onPressed: () => startNewSessionAndNavigate(context),
                )
              : null,
        );
      },
    );
  }
}
