import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gostylens/core/managers/closet_manager.dart';
import 'package:gostylens/core/services/api_service/closet_api_service.dart';
import 'package:gostylens/models/api_responses/api_response.dart';
import 'package:gostylens/models/closet_identity_status.dart';
import 'package:gostylens/models/closet_item.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FakeClosetApiService extends ClosetApiService {
  List<ClosetItem> items = const [];
  ClosetIdentityStatus status = const ClosetIdentityStatus();
  bool fail = false;
  int callCount = 0;
  int statusCallCount = 0;
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

  @override
  Future<ApiResponse<ClosetIdentityStatus>> getIdentityStatus() async {
    statusCallCount += 1;
    return ApiResponse.success(status);
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

  late FakeClosetApiService api;
  late StreamController<Map<String, dynamic>> identity;
  late StreamController<Map<String, dynamic>> catalog;
  late StreamController<RealtimeSubscribeStatus> channelStatus;
  late List<String> leftChannels;
  late ClosetManager manager;

  ClosetManager makeManager() {
    identity = StreamController<Map<String, dynamic>>.broadcast();
    catalog = StreamController<Map<String, dynamic>>.broadcast();
    channelStatus = StreamController<RealtimeSubscribeStatus>.broadcast();
    leftChannels = <String>[];
    return ClosetManager(
      apiService: api,
      onBroadcast: ({required channel, required event}) {
        if (event == ClosetManager.identityUpdatedEvent) return identity.stream;
        if (event == ClosetManager.catalogUpdatedEvent) return catalog.stream;
        return const Stream.empty();
      },
      leaveChannel: leftChannels.add,
      onChannelStatus: (_) => channelStatus.stream,
    );
  }

  setUp(() {
    api = FakeClosetApiService();
    manager = makeManager();
  });

  tearDown(() {
    manager.dispose();
    identity.close();
    catalog.close();
    channelStatus.close();
  });

  test('fetchItems stores the catalog and skips a second load', () async {
    api.items = [_tee];

    await manager.fetchItems();
    await manager.fetchItems();

    expect(api.callCount, 1);
    expect(manager.items, [_tee]);
    expect(manager.error, isNull);
    expect(manager.isLoading, isFalse);
    expect(manager.hasLoaded, isTrue);
  });

  test('forceRefresh hits the API again', () async {
    api.items = [_tee];

    await manager.fetchItems();
    await manager.fetchItems(forceRefresh: true);

    expect(api.callCount, 2);
    expect(api.lastForceRefresh, isTrue);
  });

  test('failed fetch surfaces an error and can retry', () async {
    api.fail = true;

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

  test('bindUser shows wait chrome when GET status is processing', () async {
    api.status = const ClosetIdentityStatus(processing: true, queued: 1);

    await manager.bindUser('user-1');

    expect(manager.isProcessing, isTrue);
    expect(manager.isFailedEmpty, isFalse);
    expect(api.statusCallCount, 1);
    expect(api.callCount, 1);
    expect(api.lastForceRefresh, isTrue);
  });

  test('bindUser stays idle when GET status is not processing', () async {
    await manager.bindUser('user-1');

    expect(manager.isProcessing, isFalse);
    expect(manager.identityStatus.processing, isFalse);
  });

  test('started broadcast shows chrome without hiding on later tiles', () async {
    await manager.bindUser('user-1');
    expect(manager.isProcessing, isFalse);

    identity.add({
      'processing': true,
      'queued': 1,
      'running': 0,
      'failed': 0,
      'phase': 'started',
    });
    await Future<void>.delayed(Duration.zero);

    expect(manager.isProcessing, isTrue);

    api.items = [_tee];
    catalog.add({
      'reason': 'identity',
      'outfit_id': 'o1',
      'closet_item_ids': ['1'],
    });
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(manager.isProcessing, isTrue);
    expect(manager.items, [_tee]);
  });

  test('settled broadcast hides chrome and catch-up fetches items', () async {
    api.status = const ClosetIdentityStatus(processing: true);
    await manager.bindUser('user-1');
    final itemsBeforeSettle = api.callCount;

    api.items = [_tee];
    identity.add({
      'processing': false,
      'queued': 0,
      'running': 0,
      'failed': 0,
      'phase': 'settled',
    });
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(manager.isProcessing, isFalse);
    expect(manager.items, [_tee]);
    expect(api.callCount, greaterThan(itemsBeforeSettle));
  });

  test('settled with an empty catalog marks failed empty', () async {
    api.status = const ClosetIdentityStatus(processing: true);
    await manager.bindUser('user-1');

    identity.add({
      'processing': false,
      'queued': 0,
      'running': 0,
      'failed': 1,
      'phase': 'settled',
    });
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(manager.isProcessing, isFalse);
    expect(manager.items, isEmpty);
    expect(manager.isFailedEmpty, isTrue);
  });

  test('same-user bind does not hide chrome on a quiet-window GET', () async {
    api.status = const ClosetIdentityStatus(processing: true);
    await manager.bindUser('user-1');
    expect(manager.isProcessing, isTrue);

    api.status = const ClosetIdentityStatus();
    await manager.bindUser('user-1');

    expect(manager.isProcessing, isTrue);
  });

  test('resume GET processing:false hides chrome', () async {
    api.status = const ClosetIdentityStatus(processing: true);
    await manager.bindUser('user-1');
    expect(manager.isProcessing, isTrue);

    api.status = const ClosetIdentityStatus();
    await manager.onAppResumed();

    expect(manager.isProcessing, isFalse);
  });

  test('channel subscribed catch-up hides chrome when GET is idle', () async {
    api.status = const ClosetIdentityStatus(processing: true);
    await manager.bindUser('user-1');
    expect(manager.isProcessing, isTrue);

    api.status = const ClosetIdentityStatus();
    channelStatus.add(RealtimeSubscribeStatus.subscribed);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(manager.isProcessing, isFalse);
    expect(api.statusCallCount, greaterThan(1));
  });

  test('empty catalog ping does not refresh items', () async {
    await manager.bindUser('user-1');
    final calls = api.callCount;

    catalog.add({
      'reason': 'identity',
      'outfit_id': 'o1',
      'closet_item_ids': <String>[],
    });
    await Future<void>.delayed(Duration.zero);

    expect(api.callCount, calls);
  });

  test('reset leaves the channel and clears chrome', () async {
    api.status = const ClosetIdentityStatus(processing: true);
    await manager.bindUser('user-1');

    manager.reset();

    expect(leftChannels, ['closet-identity:user-1']);
    expect(manager.isProcessing, isFalse);
    expect(manager.items, isEmpty);
    expect(manager.hasLoaded, isFalse);
  });
}
