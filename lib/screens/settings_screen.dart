import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import '../widgets/themed_scaffold.dart';
import '../services/auth_service.dart';
import '../services/auth_storage.dart';
import '../services/call_monitor_settings_service.dart';
import '../services/inference_mode_service.dart';
import '../services/mobile_bundle_service.dart';
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
  InferenceMode? _inferenceMode;
  bool _callMonitorEnabled = CallMonitorSettingsService.defaultEnabled;
  int _callMonitorChunkSeconds = CallMonitorSettingsService.defaultChunkSeconds;
  bool _callMonitorVibrate = CallMonitorSettingsService.defaultVibrateAlert;
  bool _phonePermissionGranted = false;
  bool _microphonePermissionGranted = false;
  bool _notificationPermissionGranted = true;
  bool _permissionStatusLoading = true;
  bool _diagnosticsLoading = true;
  bool _apiReachable = false;
  String _networkStatusText = 'Checking...';
  String? _backendStatusText;
  DateTime? _diagnosticsCheckedAt;

  @override
  void initState() {
    super.initState();
    _loadInferenceMode();
    _loadCallMonitorSettings();
    _refreshPermissionStatus();
    _refreshDiagnostics();
  }

  Future<void> _loadInferenceMode() async {
    final mode = await InferenceModeService.getMode();
    if (!mounted) return;
    setState(() => _inferenceMode = mode);
  }

  Future<void> _setInferenceMode(InferenceMode mode) async {
    setState(() => _inferenceMode = mode);
    await InferenceModeService.setMode(mode);
  }

  Future<void> _loadCallMonitorSettings() async {
    final enabled = await CallMonitorSettingsService.isEnabled();
    final chunkSeconds = await CallMonitorSettingsService.chunkSeconds();
    final vibrate = await CallMonitorSettingsService.vibrateAlert();
    if (!mounted) return;
    setState(() {
      _callMonitorEnabled = enabled;
      _callMonitorChunkSeconds = chunkSeconds;
      _callMonitorVibrate = vibrate;
    });
  }

  Future<void> _setCallMonitorEnabled(bool enabled) async {
    if (enabled) {
      final granted = await _ensureCallMonitorPermissions();
      await _refreshPermissionStatus();
      if (!granted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Call monitoring needs Phone, Microphone, and Notification permissions.'),
          ),
        );
        setState(() => _callMonitorEnabled = false);
        await CallMonitorSettingsService.setEnabled(false);
        return;
      }
    }
    setState(() => _callMonitorEnabled = enabled);
    await CallMonitorSettingsService.setEnabled(enabled);
  }

  Future<bool> _ensureCallMonitorPermissions() async {
    final phone = await Permission.phone.request();
    final microphone = await Permission.microphone.request();
    PermissionStatus notification = PermissionStatus.granted;
    if (Platform.isAndroid) {
      notification = await Permission.notification.request();
    }
    return phone.isGranted && microphone.isGranted && notification.isGranted;
  }

  Future<void> _refreshPermissionStatus() async {
    if (!mounted) return;
    setState(() => _permissionStatusLoading = true);

    final phone = await Permission.phone.status;
    final microphone = await Permission.microphone.status;
    PermissionStatus notification = PermissionStatus.granted;
    if (Platform.isAndroid) {
      notification = await Permission.notification.status;
    }

    if (!mounted) return;
    setState(() {
      _phonePermissionGranted = phone.isGranted;
      _microphonePermissionGranted = microphone.isGranted;
      _notificationPermissionGranted = notification.isGranted;
      _permissionStatusLoading = false;
    });
  }

  Future<void> _requestMissingPermissions() async {
    await _ensureCallMonitorPermissions();
    await _refreshPermissionStatus();
  }

  Widget _permissionChip(String label, bool granted) {
    final color = granted ? Colors.green : Colors.orange;
    final text = granted ? 'Granted' : 'Missing';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(
            granted ? Icons.check_circle_rounded : Icons.error_outline_rounded,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$label: $text',
              style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _setCallMonitorChunkSeconds(int seconds) async {
    setState(() => _callMonitorChunkSeconds = seconds);
    await CallMonitorSettingsService.setChunkSeconds(seconds);
  }

  Future<void> _setCallMonitorVibrate(bool enabled) async {
    setState(() => _callMonitorVibrate = enabled);
    await CallMonitorSettingsService.setVibrateAlert(enabled);
  }

  Future<void> _refreshDiagnostics() async {
    if (!mounted) return;
    setState(() {
      _diagnosticsLoading = true;
      _backendStatusText = null;
    });

    try {
      final connectivity = await Connectivity().checkConnectivity();
      final online = connectivity.any((c) =>
          c == ConnectivityResult.wifi ||
          c == ConnectivityResult.mobile ||
          c == ConnectivityResult.ethernet);

      final transport = online
          ? connectivity
              .where((c) => c != ConnectivityResult.none)
              .map((c) => c.name)
              .toSet()
              .join(', ')
          : 'none';

      bool apiReachable = false;
      String? backendStatus;
      if (online) {
        try {
          final info = await MobileBundleService.getBundleInfo();
          apiReachable = true;
          backendStatus = info.bundleVersion == null
              ? 'Backend reachable'
              : 'Backend reachable (bundle ${info.bundleVersion})';
        } catch (e) {
          apiReachable = false;
          backendStatus = 'Backend unreachable: $e';
        }
      } else {
        backendStatus = 'Backend check skipped (offline)';
      }

      if (!mounted) return;
      setState(() {
        _networkStatusText = online ? 'Online via $transport' : 'Offline';
        _apiReachable = apiReachable;
        _backendStatusText = backendStatus;
        _diagnosticsCheckedAt = DateTime.now();
        _diagnosticsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _networkStatusText = 'Unknown';
        _apiReachable = false;
        _backendStatusText = 'Diagnostics failed: $e';
        _diagnosticsCheckedAt = DateTime.now();
        _diagnosticsLoading = false;
      });
    }
  }

  String _formatTime(DateTime dt) {
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    final ss = dt.second.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }

  Widget _statusRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey[300] : const Color(0xFF374151),
              ),
              children: [
                TextSpan(
                  text: '$title: ',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _modeTitle(InferenceMode mode) {
    switch (mode) {
      case InferenceMode.auto:
        return 'Auto (recommended)';
      case InferenceMode.onlineOnly:
        return 'Online endpoint only';
      case InferenceMode.offlineOnly:
        return 'On-device only';
    }
  }

  String _modeSubtitle(InferenceMode mode) {
    switch (mode) {
      case InferenceMode.auto:
        return 'Uses API when reachable, falls back to on-device when needed';
      case InferenceMode.onlineOnly:
        return 'Always uses backend API for inference';
      case InferenceMode.offlineOnly:
        return 'Always uses local ONNX models on this device';
    }
  }

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
          const SizedBox(height: 16),
          _Section(
            title: 'Inference Mode',
            subtitle: 'Choose how analysis is routed',
            icon: Icons.tune_rounded,
            textColor: textColor,
            child: _inferenceMode == null
                ? const LinearProgressIndicator()
                : Column(
                    children: InferenceMode.values
                        .map(
                          (mode) => RadioListTile<InferenceMode>(
                            value: mode,
                            groupValue: _inferenceMode,
                            onChanged: (value) {
                              if (value != null) {
                                _setInferenceMode(value);
                              }
                            },
                            activeColor: AppTheme.primaryBlue,
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              _modeTitle(mode),
                              style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              _modeSubtitle(mode),
                              style: TextStyle(color: Colors.grey[600], fontSize: 13),
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'Call Monitoring',
            subtitle: 'Automatic in-call chunk analysis (Android)',
            icon: Icons.phone_in_talk_rounded,
            textColor: textColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Enable automatic call monitoring',
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Switch(
                      value: _callMonitorEnabled,
                      onChanged: (v) {
                        _setCallMonitorEnabled(v);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Chunk length: $_callMonitorChunkSeconds seconds',
                  style: TextStyle(color: Colors.grey[700], fontSize: 13),
                ),
                Slider(
                  value: _callMonitorChunkSeconds.toDouble(),
                  min: 8,
                  max: 30,
                  divisions: 11,
                  label: '$_callMonitorChunkSeconds s',
                  onChanged: _callMonitorEnabled
                      ? (v) {
                          _setCallMonitorChunkSeconds(v.round());
                        }
                      : null,
                ),
                const SizedBox(height: 4),
                Text(
                  'Longer chunks usually improve stability but increase alert latency.',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Vibrate on suspicious/fake alerts',
                        style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
                      ),
                    ),
                    Switch(
                      value: _callMonitorVibrate,
                      onChanged: _callMonitorEnabled
                          ? (v) {
                              _setCallMonitorVibrate(v);
                            }
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_permissionStatusLoading)
                  const LinearProgressIndicator()
                else ...[
                  _permissionChip('Phone', _phonePermissionGranted),
                  _permissionChip('Microphone', _microphonePermissionGranted),
                  _permissionChip('Notifications', _notificationPermissionGranted),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      TextButton.icon(
                        onPressed: _requestMissingPermissions,
                        icon: const Icon(Icons.privacy_tip_outlined, size: 18),
                        label: const Text('Request missing permissions'),
                      ),
                      TextButton.icon(
                        onPressed: _refreshPermissionStatus,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Refresh'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'System Status',
            subtitle: 'Network and backend diagnostics',
            icon: Icons.monitor_heart_rounded,
            textColor: textColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _diagnosticsLoading ? null : _refreshDiagnostics,
                    icon: _diagnosticsLoading
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Refresh status'),
                  ),
                ),
                _statusRow(
                  icon: _networkStatusText.startsWith('Online')
                      ? Icons.wifi_rounded
                      : Icons.wifi_off_rounded,
                  iconColor: _networkStatusText.startsWith('Online')
                      ? Colors.green
                      : Colors.orange,
                  title: 'Network',
                  value: _networkStatusText,
                  isDark: isDark,
                ),
                const SizedBox(height: 8),
                _statusRow(
                  icon: _apiReachable ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                  iconColor: _apiReachable ? Colors.green : Colors.orange,
                  title: 'Backend API',
                  value: _backendStatusText ?? 'Checking backend...',
                  isDark: isDark,
                ),
                if (_diagnosticsCheckedAt != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Last checked: ${_formatTime(_diagnosticsCheckedAt!)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ],
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(color: Colors.grey[700], fontSize: 13),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
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
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 12),
        Flexible(child: trailing),
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
            crossAxisAlignment: CrossAxisAlignment.start,
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
                  maxLines: 2,
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
