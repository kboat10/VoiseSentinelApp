import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../app/record_call_trigger.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_button.dart';
import '../widgets/live_voice_waveform.dart' show LiveVoiceWaveform, AudioVisualizerStyle;
import '../services/analysis_service.dart';
import '../services/history_service.dart';
import '../services/mobile_bundle_service.dart';
import '../services/wav2vec_model_manager.dart';
import '../models/history_record.dart';
import 'audio_breakdown_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isRecording = false;
  int _recordingSeconds = 0;
  Timer? _timer;
  final AudioRecorder _audioRecorder = AudioRecorder();
  final List<double> _amplitudeHistory = [];
  static const int _maxAmplitudeBars = 40;
  StreamSubscription<Amplitude>? _amplitudeSub;
  String? _currentRecordingPath;
  bool _isAnalyzing = false;
  bool _diagnosticsLoading = true;
  bool _apiReachable = false;
  String _networkStatusText = 'Checking...';
  String? _backendStatusText;
  DateTime? _diagnosticsCheckedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkRecordCallTrigger());
    unawaited(_refreshDiagnostics());
  }

  void _checkRecordCallTrigger() {
    if (RecordCallTrigger.triggered) {
      RecordCallTrigger.triggered = false;
      _showRecordCallDialog();
    }
  }

  Future<void> _showRecordCallDialog() async {
    if (!mounted) return;
    final start = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Record Call'),
        content: const Text(
          'Put the call on speaker, then tap Start to record for analysis.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Start Recording'),
          ),
        ],
      ),
    );
    if (start == true && mounted) _startRecording();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _amplitudeSub?.cancel();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final hasPermission = await _audioRecorder.hasPermission();
    if (!hasPermission) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission is required to record')),
      );
      return;
    }
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/rec_${DateTime.now().millisecondsSinceEpoch}.wav';
    _currentRecordingPath = path;
    try {
      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.wav),
        path: path,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not start recording: $e')),
      );
      _currentRecordingPath = null;
      return;
    }
    _amplitudeHistory.clear();
    _amplitudeSub = _audioRecorder
        .onAmplitudeChanged(const Duration(milliseconds: 40))
        .listen((Amplitude amp) {
      final db = amp.current.clamp(-90.0, 0.0);
      final normalized = (db + 90) / 90;
      final visible = (normalized * 0.8) + 0.2;
      if (mounted) {
        setState(() {
          _amplitudeHistory.add(visible.clamp(0.0, 1.0));
          if (_amplitudeHistory.length > _maxAmplitudeBars) {
            _amplitudeHistory.removeAt(0);
          }
        });
      }
    });
    if (!mounted) return;
    setState(() {
      _isRecording = true;
      _recordingSeconds = 0;
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _recordingSeconds++);
      });
    });
  }

  Future<void> _stopRecording() async {
    _amplitudeSub?.cancel();
    _amplitudeSub = null;
    final path = _currentRecordingPath;
    final duration = _formatDuration(_recordingSeconds);
    final seconds = _recordingSeconds;
    try {
      await _audioRecorder.stop();
    } catch (_) {}
    _timer?.cancel();
    _timer = null;
    _currentRecordingPath = null;

    if (!mounted) return;
    setState(() {
      _isRecording = false;
      _recordingSeconds = 0;
      _isAnalyzing = true;
    });

    if (path == null) {
      setState(() => _isAnalyzing = false);
      return;
    }

    if (seconds < 1) {
      setState(() => _isAnalyzing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Recording too short. Record at least 1 second for analysis.'),
        ),
      );
      return;
    }

    try {
      final result = await AnalysisService.analyze(path);
      final record = HistoryRecord(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        audioPath: path,
        duration: duration,
        result: result,
        createdAt: DateTime.now(),
      );
      await HistoryService.add(record);
      if (!mounted) return;
      setState(() => _isAnalyzing = false);
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AudioBreakdownScreen(result: result),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isAnalyzing = false);
      final message = e is PlatformException
          ? (e.message ?? e.code)
          : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Analysis failed: $message')),
      );
    }
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
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

  Widget _buildSystemStatusCard(bool isDark, Color textColor) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.monitor_heart_rounded, color: textColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'System Status',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _diagnosticsLoading ? null : _refreshDiagnostics,
                  icon: _diagnosticsLoading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Refresh'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _statusRow(
              icon: _networkStatusText.startsWith('Online')
                  ? Icons.wifi_rounded
                  : Icons.wifi_off_rounded,
              iconColor:
                  _networkStatusText.startsWith('Online') ? Colors.green : Colors.orange,
              title: 'Network',
              value: _networkStatusText,
              muted: isDark,
            ),
            const SizedBox(height: 8),
            _statusRow(
              icon: _apiReachable ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
              iconColor: _apiReachable ? Colors.green : Colors.orange,
              title: 'Backend API',
              value: _backendStatusText ?? 'Checking backend...',
              muted: isDark,
            ),
            if (Platform.isAndroid) ...[
              const SizedBox(height: 8),
              ListenableBuilder(
                listenable: Wav2Vec2ModelManager.instance,
                builder: (context, _) {
                  final manager = Wav2Vec2ModelManager.instance;
                  String value;
                  IconData icon;
                  Color color;

                  switch (manager.status) {
                    case ModelStatus.ready:
                      value = 'Ready (${manager.modelPath ?? 'cached'})';
                      icon = Icons.offline_bolt_rounded;
                      color = Colors.green;
                    case ModelStatus.downloading:
                      final pct = (manager.downloadProgress * 100).toStringAsFixed(0);
                      value = 'Downloading $pct%';
                      icon = Icons.download_rounded;
                      color = Colors.blue;
                    case ModelStatus.checking:
                      value = 'Checking local cache';
                      icon = Icons.search_rounded;
                      color = Colors.blue;
                    case ModelStatus.error:
                      value = 'Error: ${manager.errorMessage ?? 'Unknown error'}';
                      icon = Icons.error_outline_rounded;
                      color = Colors.red;
                    case ModelStatus.idle:
                      value = 'Not started yet';
                      icon = Icons.pause_circle_outline_rounded;
                      color = Colors.orange;
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _statusRow(
                        icon: icon,
                        iconColor: color,
                        title: 'Offline model',
                        value: value,
                        muted: isDark,
                      ),
                      if (manager.status == ModelStatus.downloading) ...[
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: manager.downloadProgress > 0
                              ? manager.downloadProgress
                              : null,
                        ),
                      ],
                    ],
                  );
                },
              ),
            ],
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
    );
  }

  Widget _statusRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required bool muted,
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
                color: muted ? Colors.grey[300] : const Color(0xFF374151),
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.darkTextLight : AppTheme.darkText;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Sentinel'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Call Recording',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: textColor,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Put the call on speaker, then tap Record. Analysis works online or offline.',
              style: TextStyle(
                fontSize: 15,
                color: isDark ? Colors.grey[400] : const Color(0xFF6B7280),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            _buildSystemStatusCard(isDark, textColor),
            const SizedBox(height: 32),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.lightBlue.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isRecording ? Icons.mic_rounded : Icons.mic_none_rounded,
                        color: AppTheme.lightBlue,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isAnalyzing
                          ? 'Analyzing...'
                          : _isRecording
                              ? 'Recording call...'
                              : 'Ready to record',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isRecording ? _formatDuration(_recordingSeconds) : 'Put call on speaker first',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildWaveformSection(context, textColor, isDark),
            const SizedBox(height: 16),
            _ModelStatusBanner(),
            const SizedBox(height: 16),
            GradientButton(
              label: _isAnalyzing
                  ? 'Analyzing...'
                  : _isRecording
                      ? 'Stop & Analyze'
                      : 'Start Recording',
              onPressed: _isAnalyzing ? null : (_isRecording ? _stopRecording : _startRecording),
              expand: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaveformSection(BuildContext context, Color textColor, bool isDark) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AUDIO PREVIEW',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 16),
            if (_isRecording)
              LiveVoiceWaveform(
                amplitudes: _amplitudeHistory,
                height: 72,
                barCount: 40,
                barWidth: 5,
                barSpacing: 3,
                style: AudioVisualizerStyle.waveform,
              )
            else
              Container(
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Text(
                  _isAnalyzing ? 'Processing...' : 'Tap "Start Recording" to begin',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ModelStatusBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Wav2Vec2ModelManager.instance,
      builder: (context, _) {
        final manager = Wav2Vec2ModelManager.instance;
        switch (manager.status) {
          case ModelStatus.downloading:
            final pct = (manager.downloadProgress * 100).toStringAsFixed(0);
            return _Banner(
              color: Colors.blue.shade50,
              borderColor: Colors.blue.shade200,
              icon: Icons.download_rounded,
              iconColor: Colors.blue,
              text: 'Downloading offline model... $pct%',
              child: LinearProgressIndicator(
                value: manager.downloadProgress > 0 ? manager.downloadProgress : null,
                backgroundColor: Colors.blue.shade100,
                color: Colors.blue,
              ),
            );
          case ModelStatus.checking:
            return _Banner(
              color: Colors.blue.shade50,
              borderColor: Colors.blue.shade200,
              icon: Icons.search_rounded,
              iconColor: Colors.blue,
              text: 'Checking for offline model...',
              child: const LinearProgressIndicator(),
            );
          case ModelStatus.error:
            return _Banner(
              color: Colors.orange.shade50,
              borderColor: Colors.orange.shade200,
              icon: Icons.cloud_off_rounded,
              iconColor: Colors.orange,
              text: 'Offline model unavailable. Online analysis will be used.',
              trailing: TextButton(
                onPressed: () => Wav2Vec2ModelManager.instance.retry(),
                child: const Text('Retry'),
              ),
            );
          case ModelStatus.ready:
            return _Banner(
              color: Colors.green.shade50,
              borderColor: Colors.green.shade200,
              icon: Icons.offline_bolt_rounded,
              iconColor: Colors.green,
              text: 'Offline model ready',
            );
          case ModelStatus.idle:
            return const SizedBox.shrink();
        }
      },
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.color,
    required this.borderColor,
    required this.icon,
    required this.iconColor,
    required this.text,
    this.child,
    this.trailing,
  });

  final Color color;
  final Color borderColor;
  final IconData icon;
  final Color iconColor;
  final String text;
  final Widget? child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(fontSize: 13, color: iconColor),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          if (child != null) ...[
            const SizedBox(height: 8),
            child!,
          ],
        ],
      ),
    );
  }
}
