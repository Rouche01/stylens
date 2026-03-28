import 'package:flutter/foundation.dart';

class GlobalLoaderController extends ChangeNotifier {
  GlobalLoaderController();

  bool _isLoading = false;
  String? _message;

  bool get isLoading => _isLoading;
  String? get message => _message;

  void show([String? message]) {
    _message = message;
    _isLoading = true;
    notifyListeners();
  }

  void hide() {
    _isLoading = false;
    _message = null;
    notifyListeners();
  }
}
