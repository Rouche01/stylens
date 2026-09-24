import 'package:flutter_test/flutter_test.dart';
import 'package:gostylens/core/prefs/local_prefs_service.dart';
import 'package:gostylens/core/prefs/pref_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences sp;
  late LocalPrefsService prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    sp = await SharedPreferences.getInstance();
    prefs = LocalPrefsService(sp);
    await prefs.warm();
  });

  test('get returns null and getOr uses fallback when unset', () {
    expect(prefs.get(PrefKeys.closetNotified), isNull);
    expect(prefs.getOr(PrefKeys.closetNotified, false), isFalse);
    expect(prefs.getOr(PrefKeys.pendingInviteCode, 'none'), 'none');
  });

  test('set and get round-trip supported types', () async {
    await prefs.set(PrefKeys.closetNotified, true);
    await prefs.set(PrefKeys.pendingInviteCode, 'VIP');
    await prefs.set(PrefKeys.locationCachedAt, 42);
    await prefs.set(PrefKeys.locationCachedLat, 1.5);
    await prefs.set(PrefKeys.stylistOpenersRecentIds, ['a', 'b']);

    expect(prefs.get(PrefKeys.closetNotified), isTrue);
    expect(prefs.get(PrefKeys.pendingInviteCode), 'VIP');
    expect(prefs.get(PrefKeys.locationCachedAt), 42);
    expect(prefs.get(PrefKeys.locationCachedLat), 1.5);
    expect(prefs.get(PrefKeys.stylistOpenersRecentIds), ['a', 'b']);
  });

  test('remove clears cache and disk', () async {
    await prefs.set(PrefKeys.pendingInviteCode, 'VIP');
    await prefs.remove(PrefKeys.pendingInviteCode);
    expect(prefs.get(PrefKeys.pendingInviteCode), isNull);
    expect(sp.getString(PrefKeys.pendingInviteCode.name), isNull);
  });

  test('warm hydrates a new instance from disk', () async {
    await prefs.set(PrefKeys.introWalkthroughCompleted, true);

    final again = LocalPrefsService(sp);
    await again.warm();
    expect(again.get(PrefKeys.introWalkthroughCompleted), isTrue);
  });

  test('returned string lists are copies', () async {
    await prefs.set(PrefKeys.stylistOpenersRecentIds, ['a']);
    final first = prefs.get(PrefKeys.stylistOpenersRecentIds)!;
    first.add('mutated');
    expect(prefs.get(PrefKeys.stylistOpenersRecentIds), ['a']);
  });

  test('type mismatch throws StateError', () async {
    SharedPreferences.setMockInitialValues({
      PrefKeys.introWalkthroughCompleted.name: 'not-a-bool',
    });
    final mismatched = LocalPrefsService(await SharedPreferences.getInstance());
    await mismatched.warm();

    expect(
      () => mismatched.get(PrefKeys.introWalkthroughCompleted),
      throwsA(isA<StateError>()),
    );
  });

  test('coerces untyped string lists from SharedPreferences.get', () async {
    SharedPreferences.setMockInitialValues({
      PrefKeys.stylistOpenersRecentIds.name: <Object?>['a', 'b'],
    });
    final fromDisk = LocalPrefsService(await SharedPreferences.getInstance());
    await fromDisk.warm();

    expect(fromDisk.get(PrefKeys.stylistOpenersRecentIds), ['a', 'b']);
  });
}
