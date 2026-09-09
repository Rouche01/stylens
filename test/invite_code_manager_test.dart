import 'package:flutter_test/flutter_test.dart';
import 'package:gostylens/core/managers/invite_code_manager.dart';
import 'package:gostylens/core/prefs/local_prefs_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late InviteCodeManager manager;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final sp = await SharedPreferences.getInstance();
    final prefs = LocalPrefsService(sp);
    await prefs.warm();
    manager = InviteCodeManager(prefs: prefs);
  });

  group('InviteCodeManager.normalize', () {
    test('trims and uppercases', () {
      expect(InviteCodeManager.normalize('  summer50  '), 'SUMMER50');
    });

    test('returns null for empty', () {
      expect(InviteCodeManager.normalize('   '), isNull);
      expect(InviteCodeManager.normalize(null), isNull);
    });
  });

  group('InviteCodeManager persistence', () {
    test('save read and clear round-trip', () async {
      await manager.save('vip');
      expect(await manager.read(), 'VIP');

      await manager.clear();
      expect(await manager.read(), isNull);
    });

    test('empty save clears pending code', () async {
      await manager.save('KEEP');
      await manager.save('  ');
      expect(await manager.read(), isNull);
    });
  });
}
