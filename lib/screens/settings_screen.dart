import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import '../widgets/app_bar_back.dart';
import '../widgets/themed_scaffold.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = ThemeControllerScope.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.darkTextLight : AppTheme.darkText;
    return ThemedScaffold(
      appBar: const AppBarBack(title: 'Settings'),
      padding: EdgeInsets.zero,
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _Section(
            title: 'Appearance',
            subtitle: 'Dark and light mode',
            icon: Icons.dark_mode_rounded,
            textColor: textColor,
            child: ListenableBuilder(
              listenable: themeController,
              builder: (context, _) {
                return Row(
                  children: [
                    Text(
                      'Dark mode',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Theme(
                      data: Theme.of(context).copyWith(
                        switchTheme: SwitchThemeData(
                          thumbColor: WidgetStateProperty.resolveWith((_) => AppTheme.primaryBlue),
                          trackColor: WidgetStateProperty.resolveWith((states) {
                            if (states.contains(WidgetState.selected)) {
                              return AppTheme.lightBlue.withValues(alpha: 0.6);
                            }
                            return null;
                          }),
                        ),
                      ),
                      child: Switch(
                        value: themeController.isDark,
                        onChanged: (v) => themeController.setDark(v),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'Audio',
            subtitle: 'Recording and playback',
            icon: Icons.mic_rounded,
            textColor: textColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SettingsRow(
                  title: 'Input device',
                  trailing: Text(
                    'Default',
                    style: TextStyle(color: Colors.grey[700], fontSize: 14),
                  ),
                  textColor: textColor,
                ),
                const SizedBox(height: 12),
                _SettingsRow(
                  title: 'Audio quality',
                  trailing: Text(
                    'High',
                    style: TextStyle(color: Colors.grey[700], fontSize: 14),
                  ),
                  textColor: textColor,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'Account',
            subtitle: 'Profile and data',
            icon: Icons.person_rounded,
            textColor: textColor,
            child: Column(
              children: [
                _SettingsTile(
                  icon: Icons.person_outline_rounded,
                  label: 'Edit profile',
                  onTap: () {},
                  textColor: textColor,
                ),
                const SizedBox(height: 8),
                _SettingsTile(
                  icon: Icons.help_outline_rounded,
                  label: 'Help & support',
                  onTap: () {},
                  textColor: textColor,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Center(
            child: Text(
              'Voice Sentinel v1.0',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
    required this.textColor,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.lightBlue.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: AppTheme.lightBlue, size: 24),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(color: Colors.grey[700], fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.title,
    required this.trailing,
    required this.textColor,
  });

  final String title;
  final Widget trailing;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        trailing,
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.textColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              Icon(icon, size: 22, color: AppTheme.primaryBlue),
              const SizedBox(width: 14),
              Text(
                label,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ThemeControllerScope extends InheritedNotifier<ThemeController> {
  const ThemeControllerScope({
    super.key,
    required ThemeController notifier,
    required super.child,
  }) : super(notifier: notifier);

  static ThemeController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ThemeControllerScope>();
    assert(scope != null, 'ThemeControllerScope not found');
    return scope!.notifier!;
  }
}
