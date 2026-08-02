import 'package:flutter_test/flutter_test.dart';
import 'package:gostylens/core/managers/invite_code_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late InviteCodeStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = InviteCodeStore();
  });

  group('InviteCodeStore.normalize', () {
    test('trims and uppercases', () {
      expect(InviteCodeStore.normalize('  summer50  '), 'SUMMER50');
    });

    test('returns null for empty', () {
      expect(InviteCodeStore.normalize('   '), isNull);
      expect(InviteCodeStore.normalize(null), isNull);
    });
  });

  group('InviteCodeStore persistence', () {
    test('save read and clear round-trip', () async {
      await store.save('vip');
      expect(await store.read(), 'VIP');

      await store.clear();
      expect(await store.read(), isNull);
    });

    test('empty save clears pending code', () async {
      await store.save('KEEP');
      await store.save('  ');
      expect(await store.read(), isNull);
    });
  });
}
