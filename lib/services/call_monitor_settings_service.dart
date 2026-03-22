import 'package:shared_preferences/shared_preferences.dart';

class CallMonitorSettingsService {
  CallMonitorSettingsService._();

  static const String _keyEnabled = 'call_monitor_enabled';
  static const String _keyChunkSeconds = 'call_monitor_chunk_seconds';
  static const String _keyVibrateAlert = 'call_monitor_vibrate_alert';

  static const bool defaultEnabled = false;
  static const int defaultChunkSeconds = 12;
  static const bool defaultVibrateAlert = true;

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyEnabled) ?? defaultEnabled;
  }

  static Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, enabled);
  }

  static Future<int> chunkSeconds() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getInt(_keyChunkSeconds) ?? defaultChunkSeconds;
    return value.clamp(8, 30);
  }

  static Future<void> setChunkSeconds(int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyChunkSeconds, seconds.clamp(8, 30));
  }

  static Future<bool> vibrateAlert() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyVibrateAlert) ?? defaultVibrateAlert;
  }

  static Future<void> setVibrateAlert(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyVibrateAlert, enabled);
  }
}
