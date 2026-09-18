import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostylens/core/managers/closet_manager.dart';
import 'package:gostylens/core/services/api_service/closet_api_service.dart';
import 'package:gostylens/models/api_responses/api_response.dart';
import 'package:gostylens/models/closet_identity_status.dart';
import 'package:gostylens/models/closet_item.dart';
import 'package:gostylens/pages/closet/closet_browse.dart';
import 'package:provider/provider.dart';

class _FakeClosetApiService extends ClosetApiService {
  List<ClosetItem> items = const [];
  ClosetIdentityStatus status = const ClosetIdentityStatus();
  bool fail = false;
  Completer<ApiResponse<List<ClosetItem>>>? pending;

  @override
  Future<ApiResponse<List<ClosetItem>>> getItems({
    bool forceRefresh = false,
  }) async {
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
    expect(find.text('Vintage Denim'), findsOneWidget);

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
}
