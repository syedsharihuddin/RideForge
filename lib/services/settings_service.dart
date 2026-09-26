import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static final SettingsService instance = SettingsService._init();

  static const String _keyIsMetric = 'is_metric';
  static const String _keyKeepScreenOn = 'keep_screen_on';

  SettingsService._init();

  Future<bool> isMetric() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsMetric) ?? true;
  }

  Future<void> setMetric(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsMetric, value);
  }

  Future<bool> keepScreenOn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyKeepScreenOn) ?? true;
  }

  Future<void> setKeepScreenOn(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyKeepScreenOn, value);
  }

  // Conversion helpers
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
