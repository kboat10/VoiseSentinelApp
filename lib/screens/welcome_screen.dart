import 'package:flutter/material.dart';
import '../app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_button.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _showAuth = false;
  bool _isSignUp = false;
  String _selectedUserType = AppState.regularUser;

  void _goHome() {
    if (_isSignUp) AppState.userType = _selectedUserType;
    Navigator.of(context).pushReplacementNamed('/home');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _showAuth ? _buildAuthForm(context) : _buildWelcome(context),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcome(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildVoiceSentinelLogo(context),
                const SizedBox(height: 12),
                Text(
                  'Upload or record your voice for instant analysis.',
                  textAlign: TextAlign.center,
                  style: themeTextStyle(context, 15).copyWith(
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 32),
                GradientButton(
                  label: 'Sign In / Sign Up',
                  onPressed: () => setState(() => _showAuth = true),
                  expand: true,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _goHome,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.surface,
                    foregroundColor: AppTheme.primaryBlue,
                    side: const BorderSide(color: AppTheme.primaryBlue, width: 1.5),
                    elevation: 0,
                    minimumSize: const Size(double.infinity, 54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Skip & Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAuthForm(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: _buildVoiceSentinelLogo(context)),
            const SizedBox(height: 20),
            Text(
              _isSignUp ? 'Create Account' : 'Welcome Back',
              style: themeTextStyle(context, 22, FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              _isSignUp
                  ? 'Sign up to save your voice analysis history'
                  : 'Sign in to access your account',
              style: themeTextStyle(context, 14).copyWith(color: Colors.grey[700]),
            ),
            const SizedBox(height: 24),
            TextField(
              decoration: _inputDecoration('Email', 'you@example.com'),
              keyboardType: TextInputType.emailAddress,
              style: themeTextStyle(context, 16),
            ),
            const SizedBox(height: 14),
            TextField(
              decoration: _inputDecoration('Password', '••••••••'),
              obscureText: true,
              style: themeTextStyle(context, 16),
            ),
            if (_isSignUp) ...[
              const SizedBox(height: 14),
              TextField(
                decoration: _inputDecoration('Confirm Password', '••••••••'),
                obscureText: true,
                style: themeTextStyle(context, 16),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _selectedUserType,
                decoration: _inputDecoration('User type', 'Select type'),
                items: AppState.userTypeOptions
                    .map((String value) => DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        ))
                    .toList(),
                onChanged: (String? value) {
                  if (value != null) setState(() => _selectedUserType = value);
                },
              ),
            ],
            const SizedBox(height: 24),
            GradientButton(
              label: _isSignUp ? 'Sign Up' : 'Sign In',
              onPressed: _goHome,
              expand: true,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => setState(() => _isSignUp = !_isSignUp),
              child: Text(
                _isSignUp ? 'Already have an account? Sign in' : 'Need an account? Sign up',
                style: const TextStyle(color: AppTheme.primaryBlue, fontSize: 14),
              ),
            ),
            TextButton(
              onPressed: _goHome,
              child: Text(
                'Skip for now',
                style: TextStyle(color: Colors.grey[700], fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  TextStyle themeTextStyle(BuildContext context, double fontSize, [FontWeight? fontWeight]) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextStyle(
      color: isDark ? AppTheme.darkTextLight : AppTheme.darkText,
      fontSize: fontSize,
      fontWeight: fontWeight ?? FontWeight.normal,
    );
  }

  /// Voice Sentinel logo: light blue circle with darker blue microphone.
  Widget _buildLogoPlaceholder() {
    return Container(
      width: 80,
      height: 80,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.lightBlue.withValues(alpha: 0.25),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.mic_rounded, color: AppTheme.primaryBlue, size: 40),
    );
  }

  /// Full logo block: uses asset image (icon + "Voice Sentinel" text), fallback to placeholder.
  Widget _buildVoiceSentinelLogo(BuildContext context) {
    return Image.asset(
      'assets/images/voice_sentinel_logo.png',
      height: 88,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildLogoPlaceholder(),
          const SizedBox(height: 16),
          Text(
            'Voice Sentinel',
            style: themeTextStyle(context, 22, FontWeight.bold),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, String hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(color: Colors.grey[700]),
      hintStyle: TextStyle(color: Colors.grey[500]),
      filled: true,
      fillColor: AppTheme.background,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
