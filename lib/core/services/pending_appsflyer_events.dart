import 'package:gostylens/core/prefs/local_prefs_service.dart';
import 'package:gostylens/core/prefs/pref_keys.dart';

/// AppsFlyer events waiting until the SDK has started.
///
/// The in-memory list dies if the process is killed between profile creation
/// and the tracking prompt. This queue writes each change to
/// [PrefKeys.pendingAppsFlyerEvents] before returning, and drops an event only
/// after a successful send.
class PendingAppsFlyerEventQueue {
  PendingAppsFlyerEventQueue(this._prefs);

  final LocalPrefsService _prefs;
  List<String> _wireNames = [];
  bool _loaded = false;

  List<String> get wireNames => List.unmodifiable(_wireNames);

  void load() {
    if (_loaded) return;
    _loaded = true;
    _wireNames = List<String>.from(
      _prefs.get(PrefKeys.pendingAppsFlyerEvents) ?? const <String>[],
    );
  }

  Future<void> enqueue(String wireName) async {
    load();
    _wireNames.add(wireName);
    await _persist();
  }

  /// Drops the oldest event after AppsFlyer accepted it.
  Future<void> acknowledgeFirst() async {
    load();
    if (_wireNames.isEmpty) return;
    _wireNames.removeAt(0);
    await _persist();
  }

  Future<void> _persist() async {
    if (_wireNames.isEmpty) {
      await _prefs.remove(PrefKeys.pendingAppsFlyerEvents);
      return;
    }
    await _prefs.set(
      PrefKeys.pendingAppsFlyerEvents,
      List<String>.from(_wireNames),
    );
  }
}
