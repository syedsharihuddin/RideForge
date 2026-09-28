import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static final SettingsService instance = SettingsService._init();

  static const String _keyIsMetric = 'is_metric';
  static const String _keyKeepScreenOn = 'keep_screen_on';
  static const String _keyAutomaticTracking = 'automatic_tracking';

  SettingsService._init();

  // ---------------------------------------------------------------------------
  // Measurement Units
  // ---------------------------------------------------------------------------

  Future<bool> isMetric() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsMetric) ?? true;
  }

  Future<void> setMetric(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsMetric, value);
  }

  // ---------------------------------------------------------------------------
  // Display
  // ---------------------------------------------------------------------------

  Future<bool> keepScreenOn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyKeepScreenOn) ?? true;
  }

  Future<void> setKeepScreenOn(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyKeepScreenOn, value);
  }

  // ---------------------------------------------------------------------------
  // Automatic Trip Tracking
  // ---------------------------------------------------------------------------

  /// Whether RideForge should continuously monitor location
  /// for automatic trip detection.
  ///
  /// Default is OFF so the user explicitly enables background tracking.
  Future<bool> automaticTracking() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAutomaticTracking) ?? false;
  }

  Future<void> setAutomaticTracking(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutomaticTracking, value);
  }

  // ---------------------------------------------------------------------------
  // Conversion Helpers
  // ---------------------------------------------------------------------------

  static double kmToMiles(double km) => km * 0.621371;

  static double kmhToMph(double kmh) => kmh * 0.621371;

  static String formatDistance(double distanceKm, bool isMetric) {
    if (isMetric) {
      return '${distanceKm.toStringAsFixed(2)} km';
    } else {
      return '${kmToMiles(distanceKm).toStringAsFixed(2)} mi';
    }
  }

  static String formatSpeed(double speedKmH, bool isMetric) {
    if (isMetric) {
      return '${speedKmH.toStringAsFixed(1)} km/h';
    } else {
      return '${kmhToMph(speedKmH).toStringAsFixed(1)} mph';
    }
  }

  static String speedUnit(bool isMetric) => isMetric ? 'km/h' : 'mph';

  static String distanceUnit(bool isMetric) => isMetric ? 'km' : 'mi';
}