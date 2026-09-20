import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:gostylens/core/services/api_service/base_api_service.dart';
import 'package:gostylens/models/api_responses/api_response.dart';
import 'package:gostylens/models/closet_identity_status.dart';
import 'package:gostylens/models/closet_item.dart';
import 'package:gostylens/models/closet_pending_match.dart';

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

  /// Current identity wave. Never cached — catch-up on bind / resume / tab.
  Future<ApiResponse<ClosetIdentityStatus>> getIdentityStatus() async {
    return get<ClosetIdentityStatus>(
      'identity/status',
      options: CacheOptions(
        store: MemCacheStore(),
        policy: CachePolicy.noCache,
      ).toOptions(),
      fromJson: ClosetIdentityStatus.fromResponse,
      defaultErrorMessage: 'Failed to load closet status',
    );
  }

  /// Pending identity asks. Never cached — catch-up on bind / resume / tab.
  Future<ApiResponse<List<ClosetPendingMatch>>> getPendingMatches() async {
    return get<List<ClosetPendingMatch>>(
      'matches/pending',
      options: CacheOptions(
        store: MemCacheStore(),
        policy: CachePolicy.noCache,
      ).toOptions(),
      fromJson: ClosetPendingMatch.listFromResponse,
      defaultErrorMessage: 'Failed to load closet matches',
    );
  }

  /// Resolve one ask. [decision] must be [ClosetMatchDecision.same] or
  /// [ClosetMatchDecision.asNew].
  Future<ApiResponse<ClosetMatchResolveResult>> resolveMatch({
    required String matchId,
    required ClosetMatchDecision decision,
  }) {
    if (decision != ClosetMatchDecision.same &&
        decision != ClosetMatchDecision.asNew) {
      throw ArgumentError.value(decision, 'decision', 'must be same or new');
    }
    return post<ClosetMatchResolveResult>(
      'matches/$matchId/resolve',
      body: {'decision': decision.apiValue},
      fromJson: ClosetMatchResolveResult.fromResponse,
      defaultErrorMessage: 'Failed to resolve closet match',
    );
  }
}
