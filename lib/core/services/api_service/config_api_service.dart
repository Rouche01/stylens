import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:gostylens/core/services/api_service/base_api_service.dart';
import 'package:gostylens/models/api_responses/api_response.dart';
import 'package:gostylens/models/api_responses/stylist_openers.dart';

class ConfigApiService extends BaseApiService {
  ConfigApiService() : super(resourcePath: 'config');

  /// Fetches the stylist opener pool.
  ///
  /// Pass [ifNoneMatch] (e.g. `"1"`) to allow a `304` when unchanged.
  /// On `304`, [ApiResponse.data] is `null` and [ApiResponse.isSuccess] is true.
  Future<ApiResponse<StylistOpenersPool?>> getStylistOpeners({
    String? ifNoneMatch,
  }) async {
    final headers = <String, dynamic>{};
    if (ifNoneMatch != null && ifNoneMatch.isNotEmpty) {
      headers['If-None-Match'] = ifNoneMatch;
    }

    return get<StylistOpenersPool?>(
      '/stylist-openers',
      options: CacheOptions(
        store: MemCacheStore(),
        policy: CachePolicy.noCache,
      ).toOptions().copyWith(headers: headers),
      fromJson: (data) {
        if (data == null) return null;
        if (data is Map<String, dynamic>) {
          return StylistOpenersPool.fromJson(data);
        }
        if (data is Map) {
          return StylistOpenersPool.fromJson(Map<String, dynamic>.from(data));
        }
        return null;
      },
      defaultErrorMessage: 'Failed to load stylist openers',
    );
  }
}
