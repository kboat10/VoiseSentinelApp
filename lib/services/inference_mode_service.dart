import 'package:shared_preferences/shared_preferences.dart';

enum InferenceMode { auto, onlineOnly, offlineOnly }

class InferenceModeService {
  InferenceModeService._();

  static const String _keyInferenceMode = 'inference_mode';
  static InferenceMode? _cachedMode;

  static Future<InferenceMode> getMode() async {
    if (_cachedMode != null) return _cachedMode!;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyInferenceMode);
    _cachedMode = _decode(raw);
    return _cachedMode!;
  }

  static Future<void> setMode(InferenceMode mode) async {
    _cachedMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyInferenceMode, mode.name);
  }

  static InferenceMode _decode(String? raw) {
    switch (raw) {
      case 'onlineOnly':
        return InferenceMode.onlineOnly;
      case 'offlineOnly':
        return InferenceMode.offlineOnly;
      case 'auto':
      default:
        return InferenceMode.auto;
    }
  }
}
