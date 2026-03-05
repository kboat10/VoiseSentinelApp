import 'package:flutter/material.dart';

/// Voice Sentinel theme – colors from the logo, light and dark.
class AppTheme {
  AppTheme._();

  // Colors from the Voice Sentinel logo
  static const Color primaryBlue = Color(0xFF285BAE);
  static const Color lightBlue = Color(0xFF32B5E8);
  static const Color darkText = Color(0xFF132249);
  static const Color background = Color(0xFFF8F9FA);
  static const Color surface = Colors.white;

  // Dark mode (same blue accent)
  static const Color backgroundDark = Color(0xFF0D1321);
  static const Color surfaceDark = Color(0xFF1A2332);
  static const Color darkTextLight = Color(0xFFF8F9FA);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: primaryBlue,
        secondary: lightBlue,
        surface: surface,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: darkText,
      ),
      scaffoldBackgroundColor: background,
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: darkText),
        titleTextStyle: TextStyle(
          color: darkText,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
      textTheme: const TextTheme(
        displaySmall: TextStyle(color: darkText, fontWeight: FontWeight.bold),
        titleLarge: TextStyle(color: darkText, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: darkText, fontSize: 16),
        bodyMedium: TextStyle(color: Colors.black87),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 2,
        shadowColor: primaryBlue.withValues(alpha: 0.15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: lightBlue,
        secondary: primaryBlue,
        surface: surfaceDark,
        onPrimary: darkText,
        onSurface: darkTextLight,
      ),
      scaffoldBackgroundColor: backgroundDark,
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceDark,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: darkTextLight),
        titleTextStyle: TextStyle(
          color: darkTextLight,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceDark,
        elevation: 2,
        shadowColor: Colors.black26,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  /// Gradient for primary actions (lightBlue → primaryBlue)
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [lightBlue, primaryBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
