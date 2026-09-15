import 'package:flutter_test/flutter_test.dart';
import 'package:gostylens/core/managers/closet_manager.dart';
import 'package:gostylens/core/services/api_service/closet_api_service.dart';
import 'package:gostylens/models/api_responses/api_response.dart';
import 'package:gostylens/models/closet_item.dart';

class FakeClosetApiService extends ClosetApiService {
  List<ClosetItem> items = const [];
  bool fail = false;
  int callCount = 0;
  bool? lastForceRefresh;

  @override
  Future<ApiResponse<List<ClosetItem>>> getItems({
    bool forceRefresh = false,
  }) async {
    callCount += 1;
    lastForceRefresh = forceRefresh;
    if (fail) {
      return ApiResponse.error(
        defaultMessage: 'Failed to load closet',
        statusCode: 500,
      );
    }
    return ApiResponse.success(items);
  }
}

const _tee = ClosetItem(
  id: '1',
  label: 'White tee',
  category: 'top',
  subcategory: 't-shirt',
  color: 'white',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('fetchItems stores the catalog and skips a second load', () async {
    final api = FakeClosetApiService()..items = [_tee];
    final manager = ClosetManager(apiService: api);

    await manager.fetchItems();
    await manager.fetchItems();

    expect(api.callCount, 1);
    expect(manager.items, [_tee]);
    expect(manager.error, isNull);
    expect(manager.isLoading, isFalse);
    expect(manager.hasLoaded, isTrue);
  });

  test('forceRefresh hits the API again', () async {
    final api = FakeClosetApiService()..items = [_tee];
    final manager = ClosetManager(apiService: api);

    await manager.fetchItems();
    await manager.fetchItems(forceRefresh: true);

    expect(api.callCount, 2);
    expect(api.lastForceRefresh, isTrue);
  });

  test('failed fetch surfaces an error and can retry', () async {
    final api = FakeClosetApiService()..fail = true;
    final manager = ClosetManager(apiService: api);

    await manager.fetchItems();
    expect(manager.error, isNotNull);
    expect(manager.items, isEmpty);

    api
      ..fail = false
      ..items = [_tee];
    await manager.fetchItems();

    expect(manager.error, isNull);
    expect(manager.items, [_tee]);
  });
}
