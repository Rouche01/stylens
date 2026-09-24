import 'package:gostylens/core/prefs/pref_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cached local key-value store over [SharedPreferences].
///
/// Call [warm] once at bootstrap so [get] / [getOr] are synchronous.
class LocalPrefsService {
  LocalPrefsService(this._prefs);

  final SharedPreferences _prefs;
  final Map<String, Object?> _cache = {};

  Future<void> warm() async {
    _cache.clear();
    for (final key in PrefKeys.all) {
      _cache[key.name] = _copyIfList(_prefs.get(key.name));
    }
  }

  T? get<T>(PrefKey<T> key) {
    if (!_cache.containsKey(key.name)) {
      _cache[key.name] = _copyIfList(_prefs.get(key.name));
    }
    return _cast(key, _cache[key.name]);
  }

  T getOr<T>(PrefKey<T> key, T fallback) => get(key) ?? fallback;

  Future<void> set<T>(PrefKey<T> key, T value) async {
    final stored = _copyIfList(value as Object) as T;
    _cache[key.name] = stored;
    await _writeToDisk(key.name, stored as Object);
  }

  Future<void> remove<T>(PrefKey<T> key) async {
    _cache[key.name] = null;
    await _prefs.remove(key.name);
  }

  T? _cast<T>(PrefKey<T> key, Object? value) {
    if (value == null) return null;
    final normalized = _copyIfList(value);
    if (normalized is T) return _copyIfList(normalized) as T;
    throw StateError(
      'Pref ${key.name} expected $T, got ${value.runtimeType}',
    );
  }

  Future<void> _writeToDisk(String name, Object value) {
    return switch (value) {
      final bool v => _prefs.setBool(name, v),
      final String v => _prefs.setString(name, v),
      final int v => _prefs.setInt(name, v),
      final double v => _prefs.setDouble(name, v),
      final List<String> v => _prefs.setStringList(name, v),
      _ => throw ArgumentError(
        'Unsupported pref type ${value.runtimeType} for $name',
      ),
    };
  }

  /// SharedPreferences often returns string lists as [List<Object?>] via [get].
  static Object? _copyIfList(Object? value) {
    if (value is List<String>) return List<String>.from(value);
    if (value is List) {
      final asStrings = <String>[];
      for (final item in value) {
        if (item is! String) return value;
        asStrings.add(item);
      }
      return asStrings;
    }
    return value;
  }
}
