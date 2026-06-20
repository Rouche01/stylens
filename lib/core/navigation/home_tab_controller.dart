import 'package:flutter/material.dart';

/// Shared tab index for [MyHomePage], driven by deep links and bottom nav.
class HomeTabController extends ChangeNotifier {
  static const int closetIndex = 0;
  static const int captureIndex = 1;
  static const int historyIndex = 2;

  int _tabIndex = captureIndex;

  int get tabIndex => _tabIndex;

  void setTab(int index) {
    if (_tabIndex == index) return;
    _tabIndex = index;
    notifyListeners();
  }
}
