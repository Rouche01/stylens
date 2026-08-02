import 'package:shared_preferences/shared_preferences.dart';

/// Persists a pending invite code from deep links / onboarding until profile create.
class InviteCodeStore {
  static const prefsKey = 'pending_invite_code';

  String? _cached;

  /// Normalizes and stores [code]. Empty input clears the pending code.
  Future<void> save(String code) async {
    final normalized = normalize(code);
    if (normalized == null) {
      await clear();
      return;
    }
    _cached = normalized;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsKey, normalized);
  }

  Future<String?> read() async {
    if (_cached != null && _cached!.isNotEmpty) return _cached;
    final prefs = await SharedPreferences.getInstance();
    _cached = prefs.getString(prefsKey);
    return _cached;
  }

  Future<void> clear() async {
    _cached = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefsKey);
  }

  /// Trim + uppercase; returns null when empty.
  static String? normalize(String? code) {
    if (code == null) return null;
    final normalized = code.trim().toUpperCase();
    return normalized.isEmpty ? null : normalized;
  }
}
