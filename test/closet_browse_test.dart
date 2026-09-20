import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostylens/core/managers/closet_manager.dart';
import 'package:gostylens/core/services/api_service/closet_api_service.dart';
import 'package:gostylens/models/api_responses/api_response.dart';
import 'package:gostylens/models/closet_identity_status.dart';
import 'package:gostylens/models/closet_item.dart';
import 'package:gostylens/models/closet_pending_match.dart';
import 'package:gostylens/pages/closet/closet_ask_banner.dart';
import 'package:gostylens/pages/closet/closet_ask_sheet.dart';
import 'package:gostylens/pages/closet/closet_browse.dart';
import 'package:gostylens/widgets/floating_nav_bar.dart';
import 'package:provider/provider.dart';

class _FakeClosetApiService extends ClosetApiService {
  List<ClosetItem> items = const [];
  ClosetIdentityStatus status = const ClosetIdentityStatus();
  List<ClosetPendingMatch> pendingMatches = const [];
  bool fail = false;
  int resolveStatusCode = 200;
  int getItemsCalls = 0;
  int forceRefreshCalls = 0;
  Completer<ApiResponse<List<ClosetItem>>>? pending;

  @override
  Future<ApiResponse<List<ClosetItem>>> getItems({
    bool forceRefresh = false,
  }) async {
    getItemsCalls += 1;
    if (forceRefresh) forceRefreshCalls += 1;
    if (pending != null) return pending!.future;
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
    return ApiResponse.success(status);
  }

  @override
  Future<ApiResponse<List<ClosetPendingMatch>>> getPendingMatches() async {
    return ApiResponse.success(pendingMatches);
  }

  @override
  Future<ApiResponse<ClosetMatchResolveResult>> resolveMatch({
    required String matchId,
    required ClosetMatchDecision decision,
  }) async {
    if (resolveStatusCode != 200) {
      return ApiResponse.error(
        defaultMessage: 'Failed to resolve closet match',
        statusCode: resolveStatusCode,
      );
    }
    pendingMatches = [
      for (final match in pendingMatches)
        if (match.id != matchId) match,
    ];
    return ApiResponse.success(
      ClosetMatchResolveResult(
        decision: decision,
        matchId: matchId,
        identityStatus: ClosetMatchIdentityStatus.created,
      ),
    );
  }
}

const _tee = ClosetItem(
  id: '1',
  label: 'White tee',
  category: 'top',
  subcategory: 't-shirt',
  color: 'ivory',
);

const _jeans = ClosetItem(
  id: '2',
  label: 'Vintage denim',
  category: 'bottom',
  subcategory: 'jeans',
  color: 'indigo',
);

ClosetPendingMatch _ask(String id, {String label = 'white tee'}) {
  return ClosetPendingMatch(
    id: id,
    outfitId: 'o1',
    score: 0.91,
    cosine: 0.88,
    probe: ClosetMatchSide(label: label),
    candidate: ClosetMatchSide(closetItemId: 'c-$id', label: label),
  );
}

ClosetManager _manager(_FakeClosetApiService api) {
  return ClosetManager(
    apiService: api,
    onBroadcast: ({required channel, required event}) => const Stream.empty(),
    leaveChannel: (_) {},
  );
}

Widget _app(ClosetManager manager) {
  return ChangeNotifierProvider.value(
    value: manager,
    child: const MaterialApp(home: ClosetBrowseView()),
  );
}

/// Lazy masonry estimates extent until children are laid out. Jump until
/// [maxScrollExtent] settles so the last tile is actually built.
Future<void> _jumpToScrollEnd(WidgetTester tester) async {
  final controller = tester
      .widget<CustomScrollView>(find.byType(CustomScrollView))
      .controller!;
  var previous = -1.0;
  for (var i = 0; i < 20; i++) {
    final max = controller.position.maxScrollExtent;
    if ((max - previous).abs() < 0.5 && controller.offset >= max - 0.5) {
      break;
    }
    previous = max;
    controller.jumpTo(max);
    await tester.pump();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows a skeleton grid while the first load is in flight', (
    tester,
  ) async {
    final api = _FakeClosetApiService()
      ..pending = Completer<ApiResponse<List<ClosetItem>>>();
    final manager = ClosetManager(apiService: api);

    await tester.pumpWidget(_app(manager));
    await tester.pump();

    expect(find.byKey(const ValueKey('closet-skeleton')), findsOneWidget);
    expect(find.text('Nothing hanging yet'), findsNothing);
    expect(find.text('No pieces yet'), findsNothing);

    api.pending!.complete(ApiResponse.success([_tee]));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const ValueKey('closet-skeleton')), findsNothing);
    expect(find.text('White Tee'), findsOneWidget);
  });

  testWidgets('shows an empty closet when there are no pieces', (tester) async {
    final api = _FakeClosetApiService();
    final manager = ClosetManager(apiService: api);

    await tester.pumpWidget(_app(manager));
    await tester.pump();
    await tester.pump();

    expect(find.text('Nothing hanging yet'), findsOneWidget);
    expect(find.text('Capture an outfit'), findsOneWidget);
    expect(
      find.text(
        'Capture an outfit and we’ll pull the pieces out for you. '
        'Shirts, jeans, shoes, the lot.',
      ),
      findsOneWidget,
    );
    expect(find.text('No pieces yet'), findsNothing);
    expect(find.text('Clear search'), findsNothing);
  });

  testWidgets('renders catalog labels and filters by color and subcategory', (
    tester,
  ) async {
    final api = _FakeClosetApiService()..items = [_tee, _jeans];
    final manager = ClosetManager(apiService: api);

    await tester.pumpWidget(_app(manager));
    await tester.pump();
    await tester.pump();

    expect(find.text('White Tee'), findsOneWidget);
    expect(find.text('Vintage Denim', skipOffstage: false), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'ivory');
    await tester.pump();

    expect(find.text('White Tee'), findsOneWidget);
    expect(find.text('Vintage Denim'), findsNothing);

    await tester.enterText(find.byType(TextField), 'jeans');
    await tester.pump();

    expect(find.text('White Tee'), findsNothing);
    expect(find.text('Vintage Denim'), findsOneWidget);
  });

  testWidgets('empty search copy includes the query and can clear', (
    tester,
  ) async {
    final api = _FakeClosetApiService()..items = [_tee];
    final manager = ClosetManager(apiService: api);

    await tester.pumpWidget(_app(manager));
    await tester.pump();
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'coat');
    await tester.pump();

    expect(find.text('No pieces match “coat”.'), findsOneWidget);
    expect(find.text('Nothing hanging yet'), findsNothing);
    expect(find.text('Capture an outfit'), findsNothing);
    expect(find.text('No pieces yet'), findsNothing);

    await tester.tap(find.text('Clear search'));
    await tester.pump();

    expect(find.text('White Tee'), findsOneWidget);
  });

  testWidgets('failed load shows the error and retry recovers', (tester) async {
    final api = _FakeClosetApiService()..fail = true;
    final manager = ClosetManager(apiService: api);

    await tester.pumpWidget(_app(manager));
    await tester.pump();
    await tester.pump();

    expect(find.text('Failed to load closet'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    api
      ..fail = false
      ..items = [_tee];
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump();

    expect(find.text('White Tee'), findsOneWidget);
    expect(find.text('Failed to load closet'), findsNothing);
  });

  testWidgets('categories view groups by display section', (tester) async {
    final api = _FakeClosetApiService()..items = [_tee, _jeans];
    final manager = ClosetManager(apiService: api);

    await tester.pumpWidget(_app(manager));
    await tester.pump();
    await tester.pump();

    expect(find.text('Categories'), findsOneWidget);
    expect(find.text('Tops'), findsOneWidget);
    expect(find.text('Bottoms'), findsOneWidget);
    expect(find.text('1 piece'), findsNWidgets(2));
  });

  testWidgets('All view still pull-to-refreshes when the grid fits', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final api = _FakeClosetApiService()..items = [_tee, _jeans];
    final manager = ClosetManager(apiService: api);

    await tester.pumpWidget(_app(manager));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Categories'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All').last);
    await tester.pumpAndSettle();

    final callsBefore = api.forceRefreshCalls;
    await tester.fling(
      find.byType(CustomScrollView),
      const Offset(0, 400),
      1000,
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(api.forceRefreshCalls, greaterThan(callsBefore));
    manager.dispose();
  });

  testWidgets(
    'last category tile scrolls fully above the floating dock inset',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
      tester.view.viewPadding = const FakeViewPadding(top: 59, bottom: 34);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetPadding();
        tester.view.resetViewPadding();
      });

      final api = _FakeClosetApiService()
        ..items = [
          for (var i = 0; i < 6; i++)
            ClosetItem(
              id: 't$i',
              label: 'White tee $i',
              category: 'top',
              subcategory: 't-shirt',
              color: 'white',
            ),
          _jeans,
          const ClosetItem(
            id: 'o1',
            label: 'Olive green button-up',
            category: 'outerwear',
            subcategory: 'jacket',
            color: 'olive',
          ),
          const ClosetItem(
            id: 's1',
            label: 'White canvas sneakers',
            category: 'footwear',
            subcategory: 'sneakers',
            color: 'white',
          ),
          const ClosetItem(
            id: 'a1',
            label: 'Black cap',
            category: 'accessory',
            subcategory: 'hat',
            color: 'black',
          ),
        ];
      final manager = ClosetManager(apiService: api);

      await tester.pumpWidget(_app(manager));
      await tester.pump();
      await tester.pump();

      await _jumpToScrollEnd(tester);

      final context = tester.element(find.byType(ClosetBrowseView));
      final dockInset = FloatingNavBar.contentBottomInset(context);
      final spacer = tester.getRect(
        find.byKey(ClosetBrowseView.scrollBottomInsetKey),
      );
      final tile = tester.getRect(
        find
            .ancestor(
              of: find.text('Black Cap'),
              matching: find.byType(ClipRRect),
            )
            .first,
      );
      final browse = tester.getRect(find.byType(ClosetBrowseView));

      expect(spacer.height, 16 + dockInset);
      expect(tile.bottom, lessThanOrEqualTo(spacer.top + 0.5));
      expect(tile.bottom, lessThanOrEqualTo(browse.bottom - dockInset + 0.5));
    },
  );

  testWidgets('processing empty hangs pieces and hides capture', (
    tester,
  ) async {
    final api = _FakeClosetApiService()
      ..status = const ClosetIdentityStatus(processing: true);
    final manager = _manager(api);
    await manager.bindUser('user-1');

    await tester.pumpWidget(_app(manager));
    await tester.pump();
    await tester.pump();

    expect(find.text('Hanging your pieces'), findsOneWidget);
    expect(
      find.text(
        'We’re pulling them from your outfit. They’ll land here in a moment.',
      ),
      findsOneWidget,
    );
    expect(find.text('Nothing hanging yet'), findsNothing);
    expect(find.text('Capture an outfit'), findsNothing);
    expect(find.text('Couldn’t hang that look'), findsNothing);
    expect(find.text('Hanging a few more'), findsNothing);
    expect(find.byKey(const ValueKey('closet-skeleton')), findsNothing);
    manager.dispose();
  });

  testWidgets('failed empty restores capture after a settled empty wave', (
    tester,
  ) async {
    final api = _FakeClosetApiService()
      ..status = const ClosetIdentityStatus(processing: true);
    final manager = _manager(api);
    await manager.bindUser('user-1');
    api.status = const ClosetIdentityStatus();
    await manager.syncIdentity(hideIfIdle: true);

    await tester.pumpWidget(_app(manager));
    await tester.pump();
    await tester.pump();

    expect(find.text('Couldn’t hang that look'), findsOneWidget);
    expect(
      find.text(
        'We couldn’t pull pieces from your latest outfit. '
        'Capture it again and we’ll try once more.',
      ),
      findsOneWidget,
    );
    expect(find.text('Capture an outfit'), findsOneWidget);
    expect(find.text('Hanging your pieces'), findsNothing);
    expect(find.text('Nothing hanging yet'), findsNothing);
    expect(find.text('Hanging a few more'), findsNothing);
    manager.dispose();
  });

  testWidgets('filled closet pins a dock chip while processing', (
    tester,
  ) async {
    final api = _FakeClosetApiService()
      ..items = [_tee]
      ..status = const ClosetIdentityStatus(processing: true);
    final manager = _manager(api);
    await manager.bindUser('user-1');

    await tester.pumpWidget(_app(manager));
    await tester.pump();
    await tester.pump();

    expect(find.text('White Tee'), findsOneWidget);
    expect(find.text('Hanging a few more'), findsOneWidget);
    expect(find.text('From your latest outfit'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('closet-processing-chip')),
      findsOneWidget,
    );
    expect(find.text('Hanging your pieces'), findsNothing);
    expect(find.text('Capture an outfit'), findsNothing);
    manager.dispose();
  });

  testWidgets('long-press title mimics processing on an empty closet', (
    tester,
  ) async {
    final api = _FakeClosetApiService();
    final manager = _manager(api);

    await tester.pumpWidget(_app(manager));
    await tester.pump();
    await tester.pump();

    expect(find.text('Nothing hanging yet'), findsOneWidget);

    await tester.longPress(find.text('Your Closet'));
    await tester.pump();

    expect(find.text('Hanging your pieces'), findsOneWidget);
    expect(find.text('Capture an outfit'), findsNothing);

    manager.dispose();
  });

  testWidgets('ask banner sits under the toolbar on a filled closet', (
    tester,
  ) async {
    final api = _FakeClosetApiService()
      ..items = [_tee]
      ..pendingMatches = [_ask('tee', label: 'white tee')];
    final manager = _manager(api);
    await manager.bindUser('user-1');

    await tester.pumpWidget(_app(manager));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(ClosetAskBanner.askKey), findsOneWidget);
    expect(find.text('Same white tee?'), findsOneWidget);
    expect(find.text('Looks like one already in your closet'), findsOneWidget);
    expect(find.text('0.91'), findsNothing);
    expect(find.textContaining('1 of'), findsNothing);
    expect(find.byKey(const ValueKey('closet-processing-chip')), findsNothing);
    manager.dispose();
  });

  testWidgets('ask banner stays in Categories and All', (tester) async {
    final api = _FakeClosetApiService()
      ..items = [_tee, _jeans]
      ..pendingMatches = [_ask('tee')];
    final manager = _manager(api);
    await manager.bindUser('user-1');

    await tester.pumpWidget(_app(manager));
    await tester.pump();
    await tester.pump();

    expect(find.text('Categories'), findsOneWidget);
    expect(find.text('Same white tee?'), findsOneWidget);
    expect(find.text('Tops'), findsOneWidget);

    await tester.tap(find.text('Categories'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All').last);
    await tester.pumpAndSettle();

    expect(find.text('All'), findsOneWidget);
    expect(find.text('Same white tee?'), findsOneWidget);
    expect(find.text('Tops'), findsNothing);
    manager.dispose();
  });

  testWidgets('ask banner still shows over an empty closet', (tester) async {
    final api = _FakeClosetApiService()..pendingMatches = [_ask('tee')];
    final manager = _manager(api);
    await manager.bindUser('user-1');

    await tester.pumpWidget(_app(manager));
    await tester.pump();
    await tester.pump();

    expect(find.text('Same white tee?'), findsOneWidget);
    expect(find.text('Nothing hanging yet'), findsOneWidget);
    expect(find.byKey(const ValueKey('closet-processing-chip')), findsNothing);
    manager.dispose();
  });

  testWidgets('settle banner then the next ask; last resolve hides', (
    tester,
  ) async {
    final api = _FakeClosetApiService()
      ..items = [_tee]
      ..pendingMatches = [_ask('tee'), _ask('jacket', label: 'leather jacket')];
    final manager = _manager(api);
    await manager.bindUser('user-1');

    await tester.pumpWidget(_app(manager));
    await tester.pump();
    await tester.pump();

    expect(find.text('Same white tee?'), findsOneWidget);

    await manager.resolveCurrentAsk(ClosetMatchDecision.same);
    await tester.pump();

    expect(find.byKey(ClosetAskBanner.settleKey), findsOneWidget);
    expect(find.text('Saved as the same piece'), findsOneWidget);
    expect(find.text('1 left to confirm'), findsOneWidget);
    expect(find.text('Same white tee?'), findsNothing);
    expect(find.byKey(const ValueKey('closet-processing-chip')), findsNothing);

    await tester.pump(ClosetManager.settleDwell);
    await tester.pump();

    expect(find.text('Same leather jacket?'), findsOneWidget);
    expect(find.text('Saved as the same piece'), findsNothing);

    await manager.resolveCurrentAsk(ClosetMatchDecision.asNew);
    await tester.pump();

    expect(find.byKey(ClosetAskBanner.askKey), findsNothing);
    expect(find.byKey(ClosetAskBanner.settleKey), findsNothing);
    expect(find.text('Added to closet'), findsNothing);
    manager.dispose();
  });

  testWidgets('banner tap opens the Same piece sheet', (tester) async {
    final api = _FakeClosetApiService()
      ..items = [_tee]
      ..pendingMatches = [_ask('tee')];
    final manager = _manager(api);
    await manager.bindUser('user-1');

    await tester.pumpWidget(_app(manager));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byKey(ClosetAskBanner.askKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(ClosetAskSheet.sheetKey), findsOneWidget);
    expect(find.text('Same piece?'), findsOneWidget);
    expect(find.text('New photo'), findsOneWidget);
    expect(find.text('In closet'), findsOneWidget);
    expect(find.text("It's the same"), findsOneWidget);
    expect(find.text("It's new"), findsOneWidget);
    expect(
      find.text(
        'We spotted this on a new outfit. Is it the white tee already in your closet?',
      ),
      findsOneWidget,
    );
    manager.dispose();
  });

  testWidgets('sheet same settles the banner; 409 keeps the sheet', (
    tester,
  ) async {
    final api = _FakeClosetApiService()
      ..items = [_tee]
      ..pendingMatches = [_ask('tee'), _ask('jacket', label: 'leather jacket')];
    final manager = _manager(api);
    await manager.bindUser('user-1');

    await tester.pumpWidget(_app(manager));
    await tester.pump();
    await tester.pump();

    api.resolveStatusCode = 409;
    await tester.tap(find.byKey(ClosetAskBanner.askKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(ClosetAskSheet.sameKey));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(ClosetAskSheet.sheetKey), findsOneWidget);
    expect(find.text('Same piece?'), findsOneWidget);
    expect(find.text('Same white tee?'), findsOneWidget);
    expect(manager.currentAsk?.id, 'tee');

    api.resolveStatusCode = 200;
    await tester.tap(find.byKey(ClosetAskSheet.sameKey));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(ClosetAskSheet.sheetKey), findsNothing);
    expect(find.text('Saved as the same piece'), findsOneWidget);
    expect(find.text('1 left to confirm'), findsOneWidget);
    manager.dispose();
  });
}
