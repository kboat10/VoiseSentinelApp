import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/gradient_button.dart';
import 'main_shell.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.darkTextLight : AppTheme.darkText;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Image.asset(
                'assets/images/voice_sentinel_logo.png',
                height: 120,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.mic_rounded,
                  size: 120,
                  color: AppTheme.lightBlue,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Voice Sentinel',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Protect your calls with AI-powered deepfake detection.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const Spacer(flex: 2),
              GradientButton(
                label: 'Get Started',
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const MainShell()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
