import 'package:shared_preferences/shared_preferences.dart';

/// Persists user_id across app restarts. Login state is "stuck" until logout.
class AuthStorage {
  AuthStorage._();

  static const String _keyUserId = 'auth_user_id';

  static int? _cachedUserId;

  /// Current logged-in user ID, or null if not logged in.
  static int? get userId => _cachedUserId;

  /// Whether user is logged in.
  static bool get isLoggedIn => _cachedUserId != null;

  /// Load user_id from disk. Call at app startup.
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _cachedUserId = prefs.getInt(_keyUserId);
  }

  /// Save user_id after login/register. Persists across restarts.
  static Future<void> saveUserId(int userId) async {
    _cachedUserId = userId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyUserId, userId);
  }

  /// Clear on logout.
  static Future<void> clear() async {
    _cachedUserId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUserId);
  }
}
