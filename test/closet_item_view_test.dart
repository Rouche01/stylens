import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gostylens/core/managers/closet_manager.dart';
import 'package:gostylens/core/navigation/app_navigation_keys.dart';
import 'package:gostylens/core/services/api_service/closet_api_service.dart';
import 'package:gostylens/models/api_responses/api_response.dart';
import 'package:gostylens/models/closet_identity_status.dart';
import 'package:gostylens/models/closet_item.dart';
import 'package:gostylens/models/closet_pending_match.dart';
import 'package:gostylens/navigation/app_routes.dart';
import 'package:gostylens/pages/closet/closet_browse.dart';
import 'package:gostylens/pages/closet/closet_item_hero.dart';
import 'package:gostylens/pages/closet/closet_item_recs.dart';
import 'package:gostylens/pages/closet/closet_item_view.dart';
import 'package:provider/provider.dart';

class _FakeClosetApiService extends ClosetApiService {
  List<ClosetItem> items = const [];

  @override
  Future<ApiResponse<List<ClosetItem>>> getItems({
    bool forceRefresh = false,
  }) async {
    return ApiResponse.success(items);
  }

  @override
  Future<ApiResponse<ClosetItem>> getItem(String id) async {
    for (final item in items) {
      if (item.id == id) return ApiResponse.success(item);
    }
    return ApiResponse.error(
      defaultMessage: 'Failed to load item',
      statusCode: 404,
    );
  }

  @override
  Future<ApiResponse<ClosetIdentityStatus>> getIdentityStatus() async {
    return ApiResponse.success(const ClosetIdentityStatus());
  }

  @override
  Future<ApiResponse<List<ClosetPendingMatch>>> getPendingMatches() async {
    return ApiResponse.success(const []);
  }
}

const _tee = ClosetItem(
  id: '1',
  label: 'White tee',
  category: 'top',
  subcategory: 't-shirt',
  color: 'ivory',
);

const _boxed = ClosetItem(
  id: '2',
  label: 'Leather jacket',
  category: 'outerwear',
  subcategory: 'jacket',
  color: 'black',
  boundingBox: ClosetPercentBox(x: 20, y: 10, width: 40, height: 50),
);

ClosetManager _manager(_FakeClosetApiService api) {
  return ClosetManager(
    apiService: api,
    onBroadcast: ({required channel, required event}) => const Stream.empty(),
    leaveChannel: (_) {},
  );
}

Widget _heroApp(ClosetItem item, {Size? decodedSize}) {
  return MaterialApp(
    home: Scaffold(
      body: ClosetItemHero(item: item, debugDecodedSize: decodedSize),
    ),
  );
}

Widget _viewApp(ClosetManager manager, {required String itemId}) {
  return ChangeNotifierProvider.value(
    value: manager,
    child: MaterialApp(home: ClosetItemView(itemId: itemId)),
  );
}

/// Hero is 3:4; recs sit below it and are not built on the default 800×600.
void _phoneViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('missing bounding box does not draw an overlay', (tester) async {
    await tester.pumpWidget(_heroApp(_tee, decodedSize: const Size(400, 600)));

    expect(find.text('Worn in this outfit'), findsOneWidget);
    expect(find.byKey(const ValueKey('closet-item-box-overlay')), findsNothing);
  });

  testWidgets(
    'a percent box paints the dim overlay once the photo size is known',
    (tester) async {
      await tester.pumpWidget(
        _heroApp(_boxed, decodedSize: const Size(400, 600)),
      );

      expect(
        find.byKey(const ValueKey('closet-item-box-overlay')),
        findsOneWidget,
      );
    },
  );

  testWidgets('empty recs keep copy and hide product tiles', (tester) async {
    _phoneViewport(tester);
    final api = _FakeClosetApiService()..items = [_tee];
    final manager = _manager(api);
    addTearDown(manager.dispose);
    await manager.fetchItems();

    await tester.pumpWidget(_viewApp(manager, itemId: _tee.id));
    await tester.pump();
    await tester.pump();

    expect(find.text(ClosetItemRecs.heading), findsOneWidget);
    expect(find.text(ClosetItemRecs.bodyFor('White Tee')), findsOneWidget);
    expect(find.text('None of these'), findsNothing);
    expect(find.byKey(const ValueKey('closet-item-recs-grid')), findsNothing);
  });

  testWidgets('tapping a closet tile pushes the item route', (tester) async {
    _phoneViewport(tester);
    final api = _FakeClosetApiService()..items = [_tee];
    final manager = _manager(api);
    addTearDown(manager.dispose);
    final router = GoRouter(
      initialLocation: AppRoutes.closet,
      routes: [
        GoRoute(
          path: AppRoutes.closet,
          builder: (context, state) => const ClosetBrowseView(),
        ),
        GoRoute(
          path: AppRoutes.closetItemPattern,
          builder: (context, state) =>
              ClosetItemView(itemId: state.pathParameters['id'] ?? ''),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: manager,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(ClosetItemView), findsNothing);

    await tester.tap(find.text('White Tee'));
    await tester.pump();
    await tester.pump();

    expect(find.byType(ClosetItemView), findsOneWidget);
    expect(find.text(ClosetItemRecs.heading), findsOneWidget);
    expect(router.state.uri.path, AppRoutes.closetItem(_tee.id));
  });

  testWidgets('404 on details pops back to the previous route', (tester) async {
    final api = _FakeClosetApiService();
    final manager = _manager(api);
    addTearDown(manager.dispose);
    final router = GoRouter(
      initialLocation: AppRoutes.closet,
      routes: [
        GoRoute(
          path: AppRoutes.closet,
          builder: (context, state) => const Scaffold(body: Text('grid')),
        ),
        GoRoute(
          path: AppRoutes.closetItemPattern,
          builder: (context, state) =>
              ClosetItemView(itemId: state.pathParameters['id'] ?? ''),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: manager,
        child: MaterialApp.router(
          scaffoldMessengerKey: rootScaffoldMessengerKey,
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();

    router.push(AppRoutes.closetItem('missing'));
    await tester.pump();
    await tester.pump();

    expect(find.byType(ClosetItemView), findsNothing);
    expect(find.text('grid'), findsOneWidget);
    expect(find.text('This piece is no longer in your closet'), findsOneWidget);
  });
}
