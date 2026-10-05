import 'package:flutter_test/flutter_test.dart';
import 'package:gostylens/core/prefs/local_prefs_service.dart';
import 'package:gostylens/core/prefs/pref_keys.dart';
import 'package:gostylens/core/services/pending_appsflyer_events.dart';
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

  test('enqueue survives a new queue instance', () async {
    final queue = PendingAppsFlyerEventQueue(prefs);
    await queue.enqueue('af_complete_registration');

    final restored = PendingAppsFlyerEventQueue(LocalPrefsService(sp));
    restored.load();
    expect(restored.wireNames, ['af_complete_registration']);
  });

  test('acknowledgeFirst keeps events that have not been sent', () async {
    final queue = PendingAppsFlyerEventQueue(prefs);
    await queue.enqueue('af_complete_registration');
    await queue.enqueue('af_activation');
    await queue.acknowledgeFirst();

    final restored = PendingAppsFlyerEventQueue(LocalPrefsService(sp));
    restored.load();
    expect(restored.wireNames, ['af_activation']);
  });

  test('acknowledging the last event clears the pref', () async {
    final queue = PendingAppsFlyerEventQueue(prefs);
    await queue.enqueue('af_complete_registration');
    await queue.acknowledgeFirst();

    expect(sp.getStringList(PrefKeys.pendingAppsFlyerEvents.name), isNull);
    final restored = PendingAppsFlyerEventQueue(LocalPrefsService(sp));
    restored.load();
    expect(restored.wireNames, isEmpty);
  });
}
