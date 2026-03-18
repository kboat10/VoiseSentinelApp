import 'dart:io';

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import '../widgets/themed_scaffold.dart';
import '../services/auth_service.dart';
import '../services/auth_storage.dart';
import '../services/wav2vec_model_manager.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _changingPassword = false;
  String? _changePasswordError;

  Future<void> _showChangePasswordDialog(BuildContext context) async {
    final userId = AuthStorage.userId;
    if (userId == null) return;
    final oldController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Change password'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: oldController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Current password',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: newController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'New password',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirm new password',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (_changePasswordError != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _changePasswordError!,
                      style: TextStyle(color: Colors.red[700], fontSize: 13),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: _changingPassword
                    ? null
                    : () async {
                        final oldP = oldController.text;
                        final newP = newController.text;
                        final confirm = confirmController.text;
                        if (newP != confirm) {
                          setDialogState(() => _changePasswordError = 'Passwords do not match');
                          return;
                        }
                        if (newP.isEmpty || newP.length > 72) {
                          setDialogState(() => _changePasswordError = 'New password invalid');
                          return;
                        }
                        setDialogState(() {
                          _changingPassword = true;
                          _changePasswordError = null;
                        });
                        try {
                          await AuthService.changePassword(
                            userId: userId,
                            oldPassword: oldP,
                            newPassword: newP,
                          );
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                        } on AuthException catch (e) {
                          setDialogState(() {
                            _changingPassword = false;
                            _changePasswordError = e.message;
                          });
                        } catch (e) {
                          setDialogState(() {
                            _changingPassword = false;
                            _changePasswordError = e.toString();
                          });
                        }
                      },
                child: Text(_changingPassword ? 'Changing...' : 'Change'),
              ),
            ],
          );
        },
      ),
    );
    setState(() {
      _changingPassword = false;
      _changePasswordError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeController = ThemeControllerScope.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.darkTextLight : AppTheme.darkText;
    return ThemedScaffold(
      appBar: AppBar(title: const Text('Settings')),
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
          if (Platform.isAndroid) ...[
            const SizedBox(height: 16),
            _Section(
              title: 'Offline Models',
              subtitle: 'Wav2Vec2 for on-device analysis',
              icon: Icons.download_rounded,
              textColor: textColor,
              child: ListenableBuilder(
                listenable: Wav2Vec2ModelManager.instance,
                builder: (context, _) {
                  final manager = Wav2Vec2ModelManager.instance;
                  String label;
                  String? statusText;
                  Widget? progressWidget;
                  VoidCallback? onTap;

                  switch (manager.status) {
                    case ModelStatus.ready:
                      label = 'Model ready (persists across logins)';
                      onTap = null;
                    case ModelStatus.downloading:
                      final pct = (manager.downloadProgress * 100).toStringAsFixed(0);
                      label = 'Downloading... $pct%';
                      statusText = 'Do not close the app';
                      progressWidget = LinearProgressIndicator(
                        value: manager.downloadProgress > 0 ? manager.downloadProgress : null,
                      );
                      onTap = null;
                    case ModelStatus.checking:
                      label = 'Checking for model...';
                      progressWidget = const LinearProgressIndicator();
                      onTap = null;
                    case ModelStatus.error:
                      label = 'Download failed — tap to retry';
                      statusText = manager.errorMessage;
                      onTap = () => Wav2Vec2ModelManager.instance.retry();
                    case ModelStatus.idle:
                      label = 'Download Wav2Vec2 model (~300MB)';
                      onTap = () => Wav2Vec2ModelManager.instance.ensureModel();
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (statusText != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            statusText,
                            style: TextStyle(color: Colors.grey[600], fontSize: 13),
                          ),
                        ),
                      if (progressWidget != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: progressWidget,
                        ),
                      _SettingsTile(
                        icon: manager.status == ModelStatus.ready
                            ? Icons.offline_bolt_rounded
                            : Icons.download_rounded,
                        label: label,
                        onTap: onTap ?? () {},
                        textColor: textColor,
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
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
            subtitle: 'Profile and security',
            icon: Icons.person_rounded,
            textColor: textColor,
            child: Column(
              children: [
                if (AuthStorage.userId != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Signed in as user #${AuthStorage.userId}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ),
                _SettingsTile(
                  icon: Icons.lock_reset_rounded,
                  label: 'Change password',
                  onTap: () => _showChangePasswordDialog(context),
                  textColor: textColor,
                ),
                const SizedBox(height: 8),
                _SettingsTile(
                  icon: Icons.logout_rounded,
                  label: 'Sign out',
                  onTap: () async {
                    await AuthStorage.clear();
                    if (!context.mounted) return;
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (_) => false,
                    );
                  },
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
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
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
