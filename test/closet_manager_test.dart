import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostylens/core/managers/closet_manager.dart';
import 'package:gostylens/core/services/api_service/closet_api_service.dart';
import 'package:gostylens/models/api_responses/api_response.dart';
import 'package:gostylens/models/closet_identity_status.dart';
import 'package:gostylens/models/closet_item.dart';
import 'package:gostylens/models/closet_pending_match.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FakeClosetApiService extends ClosetApiService {
  List<ClosetItem> items = const [];
  ClosetIdentityStatus status = const ClosetIdentityStatus();
  List<ClosetPendingMatch> pending = const [];
  bool fail = false;
  int callCount = 0;
  int statusCallCount = 0;
  int pendingCallCount = 0;
  int resolveCallCount = 0;
  int getItemCallCount = 0;
  ClosetItem? itemDetails;
  int getItemStatusCode = 200;
  Completer<ApiResponse<ClosetItem>>? getItemPending;
  bool? lastForceRefresh;
  String? lastResolveId;
  ClosetMatchDecision? lastResolveDecision;
  int resolveStatusCode = 200;
  ClosetMatchResolveResult? resolveResult;

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
  Future<ApiResponse<ClosetItem>> getItem(String id) async {
    getItemCallCount += 1;
    if (getItemPending != null) return getItemPending!.future;
    if (getItemStatusCode != 200) {
      return ApiResponse.error(
        defaultMessage: 'Failed to load item',
        statusCode: getItemStatusCode,
      );
    }
    final item =
        itemDetails ??
        (items.where((entry) => entry.id == id).isEmpty
            ? null
            : items.firstWhere((entry) => entry.id == id));
    if (item == null) {
      return ApiResponse.error(
        defaultMessage: 'Failed to load item',
        statusCode: 404,
      );
    }
    return ApiResponse.success(item);
  }

  @override
  Future<ApiResponse<ClosetIdentityStatus>> getIdentityStatus() async {
    statusCallCount += 1;
    return ApiResponse.success(status);
  }

  @override
  Future<ApiResponse<List<ClosetPendingMatch>>> getPendingMatches() async {
    pendingCallCount += 1;
    return ApiResponse.success(pending);
  }

  @override
  Future<ApiResponse<ClosetMatchResolveResult>> resolveMatch({
    required String matchId,
    required ClosetMatchDecision decision,
  }) async {
    resolveCallCount += 1;
    lastResolveId = matchId;
    lastResolveDecision = decision;
    if (resolveStatusCode != 200) {
      return ApiResponse.error(
        defaultMessage: 'Failed to resolve closet match',
        statusCode: resolveStatusCode,
      );
    }
    final result =
        resolveResult ??
        ClosetMatchResolveResult(
          decision: decision,
          matchId: matchId,
          identityStatus: ClosetMatchIdentityStatus.created,
        );
    if (result.decision != ClosetMatchDecision.ask) {
      pending = [
        for (final match in pending)
          if (match.id != matchId) match,
      ];
    }
    return ApiResponse.success(result);
  }
}

const _tee = ClosetItem(
  id: '1',
  label: 'White tee',
  category: 'top',
  subcategory: 't-shirt',
  color: 'white',
);

ClosetPendingMatch _ask(String id, {String label = 'white tee'}) {
  return ClosetPendingMatch(
    id: id,
    outfitId: 'o1',
    probe: ClosetMatchSide(label: label),
    candidate: ClosetMatchSide(closetItemId: 'c-$id', label: label),
  );
}

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

  test('fetchItemDetails stores a fresh original and box', () async {
    const detailed = ClosetItem(
      id: '1',
      label: 'White tee',
      category: 'top',
      subcategory: 't-shirt',
      color: 'white',
      originalImageUrl: 'https://r2.example/fresh.jpg',
      boundingBox: ClosetPercentBox(x: 20, y: 10, width: 40, height: 50),
    );
    api
      ..items = [_tee]
      ..itemDetails = detailed;

    await manager.fetchItems();
    expect(manager.itemById('1')?.boundingBox, isNull);

    final loaded = await manager.fetchItemDetails('1');
    expect(loaded?.originalImageUrl, 'https://r2.example/fresh.jpg');
    expect(manager.itemById('1')?.boundingBox?.width, 40);
    expect(manager.items.single, _tee);
    expect(api.getItemCallCount, 1);
  });

  test('fetchItemDetails surfaces 404 without changing the catalog', () async {
    api
      ..items = [_tee]
      ..getItemStatusCode = 404;

    await manager.fetchItems();
    final loaded = await manager.fetchItemDetails('1');

    expect(loaded, isNull);
    expect(manager.itemDetailsStatusCode('1'), 404);
    expect(manager.itemDetailsError('1'), isNotNull);
    expect(manager.items, [_tee]);
  });

  test('fetchItemDetails coalesces in-flight calls for the same id', () async {
    const detailed = ClosetItem(
      id: '1',
      label: 'White tee',
      category: 'top',
      subcategory: 't-shirt',
      color: 'white',
    );
    api
      ..items = [_tee]
      ..itemDetails = detailed
      ..getItemPending = Completer<ApiResponse<ClosetItem>>();

    final first = manager.fetchItemDetails('1');
    final second = manager.fetchItemDetails('1');
    expect(api.getItemCallCount, 1);
    expect(manager.isItemDetailsLoading('1'), isTrue);

    api.getItemPending!.complete(ApiResponse.success(detailed));
    expect(await first, detailed);
    expect(await second, detailed);
    expect(api.getItemCallCount, 1);
    expect(manager.isItemDetailsLoading('1'), isFalse);
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

  test(
    'started broadcast shows chrome without hiding on later tiles',
    () async {
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
    },
  );

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

  test('empty catalog ping still catch-up fetches pending asks', () async {
    await manager.bindUser('user-1');
    final itemCalls = api.callCount;
    final pendingCalls = api.pendingCallCount;

    catalog.add({
      'reason': 'identity',
      'outfit_id': 'o1',
      'closet_item_ids': <String>[],
    });
    await Future<void>.delayed(Duration.zero);

    expect(api.callCount, itemCalls);
    expect(api.pendingCallCount, greaterThan(pendingCalls));
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

  test('debug cycle pins empty wait, then failed, then idle', () async {
    await manager.bindUser('user-1');
    expect(manager.isProcessing, isFalse);

    manager.debugCycleWaitChrome();
    expect(manager.isProcessing, isTrue);
    expect(manager.isFailedEmpty, isFalse);

    api.status = const ClosetIdentityStatus();
    await manager.syncIdentity(hideIfIdle: true);
    expect(manager.isProcessing, isTrue);

    manager.debugCycleWaitChrome();
    expect(manager.isProcessing, isFalse);
    expect(manager.isFailedEmpty, isTrue);

    manager.debugCycleWaitChrome();
    expect(manager.isProcessing, isFalse);
    expect(manager.isFailedEmpty, isFalse);
  });

  test('debug cycle pins a filled catalog in processing', () async {
    api.items = [_tee];
    await manager.bindUser('user-1');

    manager.debugCycleWaitChrome();
    expect(manager.isProcessing, isTrue);
    expect(manager.items, isNotEmpty);

    manager.debugCycleWaitChrome();
    expect(manager.isProcessing, isFalse);
  });

  test('bindUser loads pending newest-first as currentAsk', () async {
    api.pending = [_ask('newer'), _ask('older', label: 'navy jacket')];

    await manager.bindUser('user-1');

    expect(api.pendingCallCount, 1);
    expect(manager.currentAsk?.id, 'newer');
    expect(manager.pendingMatches.map((m) => m.id), ['newer', 'older']);
    expect(manager.askSettle, isNull);
  });

  test('resume and subscribed catch-up fetch pending', () async {
    await manager.bindUser('user-1');
    api.pending = [_ask('m1')];

    await manager.onAppResumed();
    expect(manager.currentAsk?.id, 'm1');

    api.pending = [_ask('m2')];
    channelStatus.add(RealtimeSubscribeStatus.subscribed);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(manager.currentAsk?.id, 'm2');
    expect(api.pendingCallCount, greaterThan(2));
  });

  test('settled catch-up fetches pending', () async {
    api.status = const ClosetIdentityStatus(processing: true);
    await manager.bindUser('user-1');
    api.pending = [_ask('after-settle')];

    identity.add({
      'processing': false,
      'queued': 0,
      'running': 0,
      'failed': 0,
      'phase': 'settled',
    });
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(manager.currentAsk?.id, 'after-settle');
  });

  test('resolve same settles then shows the next ask', () {
    fakeAsync((async) {
      api.pending = [_ask('tee'), _ask('jacket', label: 'leather jacket')];
      manager.bindUser('user-1');
      async.flushMicrotasks();

      var closed = false;
      manager.resolveCurrentAsk(ClosetMatchDecision.same).then((ok) {
        closed = ok;
      });
      async.flushMicrotasks();

      expect(closed, isTrue);
      expect(api.lastResolveId, 'tee');
      expect(api.lastResolveDecision, ClosetMatchDecision.same);
      expect(manager.currentAsk, isNull);
      expect(manager.askSettle?.kind, ClosetAskSettleKind.savedSame);
      expect(manager.askSettle?.remaining, 1);
      expect(manager.askSettle?.remainingLine, '1 left to confirm');

      async.elapse(ClosetManager.settleDwell);
      expect(manager.askSettle, isNull);
      expect(manager.currentAsk?.id, 'jacket');
    });
  });

  test('resolve new refreshes items and settle copy is Added', () {
    fakeAsync((async) {
      api.pending = [_ask('jacket'), _ask('shoes', label: 'court sneakers')];
      manager.bindUser('user-1');
      async.flushMicrotasks();
      final itemsBefore = api.callCount;

      manager.resolveCurrentAsk(ClosetMatchDecision.asNew);
      async.flushMicrotasks();

      expect(api.callCount, greaterThan(itemsBefore));
      expect(manager.askSettle?.kind, ClosetAskSettleKind.added);
      expect(manager.askSettle?.title, 'Added to closet');
      async.elapse(ClosetManager.settleDwell);
      expect(manager.askSettle, isNull);
      expect(manager.currentAsk?.id, 'shoes');
    });
  });

  test('last resolve hides without a settle flash', () {
    fakeAsync((async) {
      api.pending = [_ask('only')];
      manager.bindUser('user-1');
      async.flushMicrotasks();

      manager.resolveCurrentAsk(ClosetMatchDecision.same);
      async.flushMicrotasks();

      expect(manager.askSettle, isNull);
      expect(manager.currentAsk, isNull);
      expect(manager.pendingMatches, isEmpty);
    });
  });

  test('409 keeps the current ask for the sheet', () {
    fakeAsync((async) {
      api.pending = [_ask('tee')];
      manager.bindUser('user-1');
      async.flushMicrotasks();

      api.resolveStatusCode = 409;
      var closed = true;
      manager.resolveCurrentAsk(ClosetMatchDecision.same).then((ok) {
        closed = ok;
      });
      async.flushMicrotasks();

      expect(closed, isFalse);
      expect(manager.currentAsk?.id, 'tee');
      expect(manager.askSettle, isNull);
      expect(manager.matchResolveError, isNotNull);
    });
  });

  test('404 drops the match and catch-up GETs pending', () {
    fakeAsync((async) {
      api.pending = [_ask('gone'), _ask('next')];
      manager.bindUser('user-1');
      async.flushMicrotasks();

      api.resolveStatusCode = 404;
      var closed = false;
      manager.resolveCurrentAsk(ClosetMatchDecision.same).then((ok) {
        closed = ok;
      });
      async.flushMicrotasks();

      expect(closed, isTrue);
      expect(manager.currentAsk?.id, 'next');
      expect(manager.askSettle, isNull);
    });
  });

  test('resolve ask refetches pending and does not show Added', () {
    fakeAsync((async) {
      api.pending = [_ask('tee')];
      manager.bindUser('user-1');
      async.flushMicrotasks();

      api.resolveResult = const ClosetMatchResolveResult(
        decision: ClosetMatchDecision.ask,
        matchId: 'tee-2',
        identityStatus: ClosetMatchIdentityStatus.ask,
      );
      api.pending = [_ask('tee-2')];
      manager.resolveCurrentAsk(ClosetMatchDecision.asNew);
      async.flushMicrotasks();

      expect(manager.askSettle, isNull);
      expect(manager.currentAsk?.id, 'tee-2');
    });
  });

  test('reset clears pending and a running settle timer', () {
    fakeAsync((async) {
      api.pending = [_ask('tee'), _ask('jacket')];
      manager.bindUser('user-1');
      async.flushMicrotasks();
      manager.resolveCurrentAsk(ClosetMatchDecision.same);
      async.flushMicrotasks();
      expect(manager.askSettle, isNotNull);

      manager.reset();

      expect(manager.currentAsk, isNull);
      expect(manager.askSettle, isNull);
      expect(manager.pendingMatches, isEmpty);
      async.elapse(ClosetManager.settleDwell);
      expect(manager.askSettle, isNull);
    });
  });
}
