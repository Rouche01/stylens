import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' as permission_handler;
import 'package:shared_preferences/shared_preferences.dart';

enum LocationAccessResult {
  granted,
  denied,
  deniedForever,
  servicesDisabled,
  userPreviouslyDeclined,
}

class GeoCoordinates {
  const GeoCoordinates({
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;
}

class LocationManager {
  static const _explainerShownKey = 'location_explainer_shown';
  static const _userDeclinedKey = 'location_user_declined';
  static const _cachedLatKey = 'location_cached_lat';
  static const _cachedLngKey = 'location_cached_lng';
  static const _cachedAtKey = 'location_cached_at';
  static const _cacheTtl = Duration(minutes: 30);

  Future<bool> hasShownExplainer() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_explainerShownKey) ?? false;
  }

  Future<void> markExplainerShown({required bool userDeclined}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_explainerShownKey, true);
    if (userDeclined) {
      await prefs.setBool(_userDeclinedKey, true);
    }
  }

  Future<bool> _hasUserDeclined() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_userDeclinedKey) ?? false;
  }

  Future<bool> hasPermission() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<LocationPermission> currentStatus() {
    return Geolocator.checkPermission();
  }

  Future<LocationAccessResult> ensureAccess() async {
    if (await _hasUserDeclined()) {
      return LocationAccessResult.userPreviouslyDeclined;
    }

    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationAccessResult.servicesDisabled;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      return LocationAccessResult.deniedForever;
    }

    if (permission == LocationPermission.denied) {
      return LocationAccessResult.denied;
    }

    return LocationAccessResult.granted;
  }

  /// Returns coordinates when permission is already granted. Never prompts.
  /// Uses a cached reading when fresh (within [_cacheTtl]).
  Future<GeoCoordinates?> getCurrentPosition() async {
    if (!await hasPermission()) return null;

    final cached = await _readCachedCoordinates();
    if (cached != null) return cached;

    if (!await Geolocator.isLocationServiceEnabled()) return null;

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 10),
        ),
      );
      final coordinates = GeoCoordinates(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      await _cacheCoordinates(coordinates);
      return coordinates;
    } catch (_) {
      return null;
    }
  }

  Future<GeoCoordinates?> _readCachedCoordinates() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble(_cachedLatKey);
    final lng = prefs.getDouble(_cachedLngKey);
    final cachedAtMs = prefs.getInt(_cachedAtKey);
    if (lat == null || lng == null || cachedAtMs == null) return null;

    final cachedAt = DateTime.fromMillisecondsSinceEpoch(cachedAtMs);
    if (DateTime.now().difference(cachedAt) > _cacheTtl) return null;

    return GeoCoordinates(latitude: lat, longitude: lng);
  }

  Future<void> _cacheCoordinates(GeoCoordinates coordinates) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_cachedLatKey, coordinates.latitude);
    await prefs.setDouble(_cachedLngKey, coordinates.longitude);
    await prefs.setInt(_cachedAtKey, DateTime.now().millisecondsSinceEpoch);
  }

  Future<bool> openSettings() {
    return permission_handler.openAppSettings();
  }
}
