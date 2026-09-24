import 'package:flutter_test/flutter_test.dart';
import 'package:gostylens/core/config/feature_flags.dart';
import 'package:gostylens/core/managers/closet_manager.dart';
import 'package:gostylens/core/services/api_service/closet_api_service.dart';
import 'package:gostylens/core/services/feature_flag_service.dart';
import 'package:gostylens/models/api_responses/api_response.dart';
import 'package:gostylens/models/closet_identity_status.dart';
import 'package:gostylens/models/closet_item.dart';
import 'package:gostylens/models/closet_pending_match.dart';
import 'package:gostylens/navigation/app_router.dart';
import 'package:gostylens/navigation/app_routes.dart';

class _FakeClosetApiService extends ClosetApiService {
  int itemsCalls = 0;
  int statusCalls = 0;
  int pendingCalls = 0;
  int detailCalls = 0;

  @override
  Future<ApiResponse<List<ClosetItem>>> getItems({
    bool forceRefresh = false,
  }) async {
    itemsCalls += 1;
    return ApiResponse.success(const []);
  }

  @override
  Future<ApiResponse<ClosetIdentityStatus>> getIdentityStatus() async {
    statusCalls += 1;
    return ApiResponse.success(const ClosetIdentityStatus());
  }

  @override
  Future<ApiResponse<List<ClosetPendingMatch>>> getPendingMatches() async {
    pendingCalls += 1;
    return ApiResponse.success(const []);
  }

  @override
  Future<ApiResponse<ClosetItem>> getItem(String id) async {
    detailCalls += 1;
    return ApiResponse.success(
      const ClosetItem(
        id: '1',
        label: 'tee',
        category: 'top',
        subcategory: 't-shirt',
        color: 'white',
      ),
    );
  }
}

ClosetManager _closet(
  _FakeClosetApiService api, {
  required bool browseEnabled,
}) {
  return ClosetManager(
    apiService: api,
    onBroadcast: ({required channel, required event}) => const Stream.empty(),
    leaveChannel: (_) {},
    browseEnabled: () async => browseEnabled,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('caches flag snapshot until cleared', () async {
    var calls = 0;
    var remote = <String, Object>{FeatureFlags.closetBrowse: false};
    final flags = FeatureFlagService(
      overrides: const {},
      fetchFeatures: () async {
        calls += 1;
        return remote;
      },
    );

    expect(await flags.closetBrowseEnabled(), isFalse);
    expect(await flags.closetBrowseEnabled(), isFalse);
    expect(calls, 1);

    remote = {FeatureFlags.closetBrowse: true};
    flags.clear();

    expect(await flags.closetBrowseEnabled(), isTrue);
    expect(calls, 2);
  });

  test('one snapshot serves every key', () async {
    var calls = 0;
    final flags = FeatureFlagService(
      overrides: const {},
      fetchFeatures: () async {
        calls += 1;
        return {
          FeatureFlags.closetBrowse: true,
          'other': true,
        };
      },
    );

    expect(await flags.isEnabled('other'), isTrue);
    expect(await flags.isEnabled(FeatureFlags.closetBrowse), isTrue);
    expect(calls, 1);
  });

  test('failed refresh keeps the previous map', () async {
    var calls = 0;
    final flags = FeatureFlagService(
      overrides: const {},
      fetchFeatures: () async {
        calls += 1;
        if (calls == 1) {
          return {FeatureFlags.closetBrowse: true};
        }
        return null;
      },
    );

    expect(await flags.closetBrowseEnabled(), isTrue);
    await flags.refresh();
    expect(await flags.closetBrowseEnabled(), isTrue);
    expect(flags.snapshot?[FeatureFlags.closetBrowse], isTrue);
    expect(calls, 2);
  });

  test('empty first response leaves flags off', () async {
    final flags = FeatureFlagService(
      overrides: const {},
      fetchFeatures: () async => const {},
    );

    expect(await flags.closetBrowseEnabled(), isFalse);
    expect(await flags.isEnabled('other'), isFalse);
    expect(flags.hasSnapshot, isTrue);
    expect(flags.snapshot, isEmpty);
  });

  test('debug overrides beat the API map', () async {
    var calls = 0;
    final flags = FeatureFlagService(
      overrides: const {FeatureFlags.closetBrowse: true},
      fetchFeatures: () async {
        calls += 1;
        return {FeatureFlags.closetBrowse: false};
      },
    );

    expect(await flags.closetBrowseEnabled(), isTrue);
    expect(calls, 0);
  });

  test('skips closet sync when browse is off', () async {
    final api = _FakeClosetApiService();
    final closet = _closet(api, browseEnabled: false);
    addTearDown(closet.dispose);

    await closet.bindUser('user-1');
    await closet.fetchPendingMatches();
    await closet.fetchItemDetails('1');

    expect(api.itemsCalls, 0);
    expect(api.statusCalls, 0);
    expect(api.pendingCalls, 0);
    expect(api.detailCalls, 0);
    expect(closet.isProcessing, isFalse);
  });

  test('binds closet when browse is on', () async {
    final api = _FakeClosetApiService();
    final closet = _closet(api, browseEnabled: true);
    addTearDown(closet.dispose);

    await closet.bindUser('user-1');
    await closet.fetchItemDetails('1');

    expect(api.itemsCalls, greaterThan(0));
    expect(api.statusCalls, greaterThan(0));
    expect(api.pendingCalls, greaterThan(0));
    expect(api.detailCalls, 1);
  });

  test('redirects a closet item route to the tab when browse is off', () {
    expect(
      redirectForClosetBrowse(
        location: AppRoutes.closetItem('c1'),
        browseEnabled: false,
      ),
      AppRoutes.closet,
    );
    expect(
      redirectForClosetBrowse(
        location: AppRoutes.closetItem('c1'),
        browseEnabled: true,
      ),
      isNull,
    );
    expect(
      redirectForClosetBrowse(
        location: AppRoutes.capture,
        browseEnabled: false,
      ),
      isNull,
    );
  });
}
