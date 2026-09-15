import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:gostylens/core/services/api_service/base_api_service.dart';
import 'package:gostylens/models/api_responses/api_response.dart';
import 'package:gostylens/models/closet_item.dart';

class ClosetApiService extends BaseApiService {
  ClosetApiService() : super(resourcePath: 'closet');

  /// Authenticated closet catalog. `{ items: ClosetItem[] }` — no pagination.
  Future<ApiResponse<List<ClosetItem>>> getItems({
    bool forceRefresh = false,
  }) async {
    return get<List<ClosetItem>>(
      'items',
      options: CacheOptions(
        store: MemCacheStore(),
        policy: forceRefresh
            ? CachePolicy.refreshForceCache
            : CachePolicy.noCache,
      ).toOptions(),
      fromJson: ClosetItem.listFromResponse,
      defaultErrorMessage: 'Failed to load closet',
    );
  }
}
