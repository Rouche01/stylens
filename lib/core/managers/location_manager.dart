import 'package:geolocator/geolocator.dart';
import 'package:gostylens/core/config/dependency_injection.dart';
import 'package:gostylens/core/prefs/local_prefs_service.dart';
import 'package:gostylens/core/prefs/pref_keys.dart';

enum LocationAccessResult {
  granted,
  denied,
  deniedForever,
  servicesDisabled,
  userPreviouslyDeclined,
}

class GeoCoordinates {
  const GeoCoordinates({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

class LocationManager {
  LocationManager({LocalPrefsService? prefs})
    : _prefs = prefs ?? locator<LocalPrefsService>();

  final LocalPrefsService _prefs;
  static const _cacheTtl = Duration(minutes: 30);

  Future<bool> hasShownExplainer() async {
    return _prefs.getOr(PrefKeys.locationExplainerShown, false);
  }

  Future<void> markExplainerShown({required bool userDeclined}) async {
    await _prefs.set(PrefKeys.locationExplainerShown, true);
    if (userDeclined) {
      await _prefs.set(PrefKeys.locationUserDeclined, true);
    }
  }

  Future<bool> _hasUserDeclined() async {
    return _prefs.getOr(PrefKeys.locationUserDeclined, false);
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

    final cached = _readCachedCoordinates();
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

  GeoCoordinates? _readCachedCoordinates() {
    final lat = _prefs.get(PrefKeys.locationCachedLat);
    final lng = _prefs.get(PrefKeys.locationCachedLng);
    final cachedAtMs = _prefs.get(PrefKeys.locationCachedAt);
    if (lat == null || lng == null || cachedAtMs == null) return null;

    final cachedAt = DateTime.fromMillisecondsSinceEpoch(cachedAtMs);
    if (DateTime.now().difference(cachedAt) > _cacheTtl) return null;

    return GeoCoordinates(latitude: lat, longitude: lng);
  }

  Future<void> _cacheCoordinates(GeoCoordinates coordinates) async {
    await _prefs.set(PrefKeys.locationCachedLat, coordinates.latitude);
    await _prefs.set(PrefKeys.locationCachedLng, coordinates.longitude);
    await _prefs.set(
      PrefKeys.locationCachedAt,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<bool> openSettings() {
    return Geolocator.openAppSettings();
  }
}
