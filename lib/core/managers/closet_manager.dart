import 'package:flutter/foundation.dart';
import 'package:gostylens/core/config/dependency_injection.dart';
import 'package:gostylens/core/services/api_service/closet_api_service.dart';
import 'package:gostylens/models/closet_item.dart';

/// Server closet list. Search and All/Categories stay in the browse view.
class ClosetManager extends ChangeNotifier {
  ClosetManager({ClosetApiService? apiService})
    : _apiService = apiService ?? locator<ClosetApiService>();

  final ClosetApiService _apiService;

  List<ClosetItem> _items = const [];
  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _error;

  List<ClosetItem> get items => _items;
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  String? get error => _error;

  Future<void> fetchItems({bool forceRefresh = false}) async {
    if (_isLoading) return;
    if (_hasLoaded && !forceRefresh && _error == null) return;

    final showSpinner = !_hasLoaded || _items.isEmpty;
    _isLoading = showSpinner;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.getItems(forceRefresh: forceRefresh);
      if (response.isSuccess) {
        _items = List<ClosetItem>.unmodifiable(response.data ?? const []);
        _hasLoaded = true;
        _error = null;
      } else {
        _error = response.errorMessage;
        _hasLoaded = true;
      }
    } catch (e, st) {
      debugPrint('ClosetManager.fetchItems failed: $e\n$st');
      _error = 'Failed to load closet';
      _hasLoaded = true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
