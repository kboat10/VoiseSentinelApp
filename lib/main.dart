import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';
import 'screens/welcome_screen.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/change_user_type_screen.dart';
import 'screens/audio_breakdown_screen.dart';

void main() {
  runApp(const VoiceSentinelApp());
}

class VoiceSentinelApp extends StatefulWidget {
  const VoiceSentinelApp({super.key});

  @override
  State<VoiceSentinelApp> createState() => _VoiceSentinelAppState();
}

class _VoiceSentinelAppState extends State<VoiceSentinelApp> {
  final _themeController = ThemeController();

  @override
  void dispose() {
    _themeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _themeController,
      builder: (context, _) {
        return MaterialApp(
          title: 'Voice Sentinel',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: _themeController.mode,
          debugShowCheckedModeBanner: false,
          builder: (context, child) {
            return ThemeControllerScope(
              notifier: _themeController,
              child: child!,
            );
          },
          home: const WelcomeScreen(),
          routes: {
            '/home': (context) => const HomeScreen(),
            '/settings': (context) => const SettingsScreen(),
            '/change-user-type': (context) => const ChangeUserTypeScreen(),
            '/audio-breakdown': (context) => const AudioBreakdownScreen(),
          },
        );
      },
    );
  }
}
