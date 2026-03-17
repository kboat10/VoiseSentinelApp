import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Auth API client matching web app: register, login, change-password.
/// Uses application/x-www-form-urlencoded.
class AuthService {
  AuthService._();

  static const String _baseUrl = 'http://45.55.247.199/api';

  /// Register a new user.
  /// Returns user_id on success.
  /// Throws on 409 (email exists), 422 (validation), or network error.
  static String _encodeForm(Map<String, String> data) {
    return data.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  static Future<int> register({
    required String email,
    required String password,
    String level = 'BASIC',
  }) async {
    final uri = Uri.parse('$_baseUrl/auth/register');
    final body = _encodeForm({
      'email': email,
      'password': password,
      'level': level,
    });
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: body,
    ).timeout(const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException('Request timed out. Check your connection.'));

    if (response.statusCode == 409) {
      throw AuthException('Email already registered', code: 409);
    }
    if (response.statusCode == 422) {
      throw AuthException(_parseValidationError(response.body), code: 422);
    }
    if (response.statusCode != 200) {
      throw AuthException('Registration failed: ${response.statusCode}', code: response.statusCode);
    }

    final json = _parseJson(response.body);
    final userId = json['user_id'];
    if (userId == null) {
      throw AuthException('Invalid response: no user_id', code: 500);
    }
    return (userId is num) ? userId.toInt() : int.parse(userId.toString());
  }

  /// Login with email and password.
  /// Returns user_id (token) on success.
  /// Throws on 401 (invalid credentials), 422 (validation), or network error.
  static Future<int> login({
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse('$_baseUrl/auth/login');
    final body = _encodeForm({
      'email': email,
      'password': password,
    });
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: body,
    ).timeout(const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException('Request timed out. Check your connection.'));

    if (response.statusCode == 401) {
      throw AuthException('Invalid email or password', code: 401);
    }
    if (response.statusCode == 422) {
      throw AuthException(_parseValidationError(response.body), code: 422);
    }
    if (response.statusCode != 200) {
      throw AuthException('Login failed: ${response.statusCode}', code: response.statusCode);
    }

    final json = _parseJson(response.body);
    final token = json['token'];
    if (token == null) {
      throw AuthException('Invalid response: no token', code: 500);
    }
    return (token is num) ? token.toInt() : int.parse(token.toString());
  }

  /// Change password for logged-in user.
  /// Throws on 403 (old password wrong), 422 (validation), or network error.
  static Future<void> changePassword({
    required int userId,
    required String oldPassword,
    required String newPassword,
  }) async {
    final uri = Uri.parse('$_baseUrl/auth/change-password');
    final body = _encodeForm({
      'user_id': userId.toString(),
      'old': oldPassword,
      'new': newPassword,
    });
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: body,
    ).timeout(const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException('Request timed out. Check your connection.'));

    if (response.statusCode == 403) {
      throw AuthException('Old password is incorrect', code: 403);
    }
    if (response.statusCode == 422) {
      throw AuthException(_parseValidationError(response.body), code: 422);
    }
    if (response.statusCode != 200) {
      throw AuthException('Change password failed: ${response.statusCode}', code: response.statusCode);
    }
  }

  static String _parseValidationError(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>?;
      final detail = json?['detail'];
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map && first['msg'] != null) {
          return first['msg'] as String;
        }
      }
    } catch (_) {}
    return 'Validation error';
  }

  static Map<String, dynamic> _parseJson(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : {};
    } catch (_) {
      return {};
    }
  }
}

class AuthException implements Exception {
  AuthException(this.message, {this.code});

  final String message;
  final int? code;

  @override
  String toString() => message;
}
