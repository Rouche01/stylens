import 'package:flutter/material.dart';
import 'package:gostylens/core/managers/global_loader/global_loader_scope.dart';
import 'package:gostylens/pages/capture.dart';
import 'package:gostylens/pages/closet.dart';
import 'package:gostylens/pages/history.dart';

class MyHomePage extends StatefulWidget {
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  var selectedIndex = 1;

  @override
  Widget build(BuildContext context) {
    Widget page;

    switch (selectedIndex) {
      case 0:
        page = ClosetPage();
      case 1:
        page = CapturePage();
      case 2:
        page = HistoryPage(
          onStartConversation: () => setState(() => selectedIndex = 1),
        );
      default:
        throw UnimplementedError('no widget for $selectedIndex');
    }

    return GlobalLoaderScope(
      child: Scaffold(
        body: page,
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          items: [
            BottomNavigationBarItem(
              icon: Icon(Icons.checkroom),
              label: 'Closet',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.camera_alt),
              label: 'Capture',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history),
              label: 'History',
            ),
          ],
          currentIndex: selectedIndex,
          onTap: (index) {
            setState(() {
              selectedIndex = index;
            });
          },
        ),
      ),
    );
  }
}
