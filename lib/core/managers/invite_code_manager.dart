import 'package:gostylens/core/config/dependency_injection.dart';
import 'package:gostylens/core/prefs/local_prefs_service.dart';
import 'package:gostylens/core/prefs/pref_keys.dart';

/// Persists a pending invite code from deep links / onboarding until profile create.
class InviteCodeManager {
  InviteCodeManager({LocalPrefsService? prefs})
    : _prefs = prefs ?? locator<LocalPrefsService>();

  final LocalPrefsService _prefs;

  /// Normalizes and stores [code]. Empty input clears the pending code.
  Future<void> save(String code) async {
    final normalized = normalize(code);
    if (normalized == null) {
      await clear();
      return;
    }
    await _prefs.set(PrefKeys.pendingInviteCode, normalized);
  }

  Future<String?> read() async {
    return _prefs.get(PrefKeys.pendingInviteCode);
  }

  Future<void> clear() async {
    await _prefs.remove(PrefKeys.pendingInviteCode);
  }

  /// Trim + uppercase; returns null when empty.
  static String? normalize(String? code) {
    if (code == null) return null;
    final normalized = code.trim().toUpperCase();
    return normalized.isEmpty ? null : normalized;
  }
}
