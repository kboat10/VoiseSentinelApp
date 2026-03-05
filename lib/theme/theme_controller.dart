import 'package:flutter/material.dart';

/// Holds theme mode (light / dark / system) and notifies listeners.
class ThemeController extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.light;

  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;

  set mode(ThemeMode value) {
    if (_mode == value) return;
    _mode = value;
    notifyListeners();
  }

  void setDark(bool dark) {
    mode = dark ? ThemeMode.dark : ThemeMode.light;
  }

  void toggle() {
    mode = _mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
  }
}
