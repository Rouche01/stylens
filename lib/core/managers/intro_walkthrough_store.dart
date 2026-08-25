import 'package:shared_preferences/shared_preferences.dart';

/// Persists whether the pre-login intro walkthrough has been completed/skipped.
class IntroWalkthroughStore {
  static const prefsKey = 'intro_walkthrough_completed';

  bool? _cached;

  /// Loads the flag into memory so redirects can read it synchronously.
  Future<void> warm() async {
    final prefs = await SharedPreferences.getInstance();
    _cached = prefs.getBool(prefsKey) ?? false;
  }

  /// Whether the user has finished or skipped the intro on this install.
  bool get hasCompleted => _cached ?? false;

  Future<void> markCompleted() async {
    _cached = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefsKey, true);
  }
}
