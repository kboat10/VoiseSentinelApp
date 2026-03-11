import 'dart:async';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkRecordCallTrigger());
  }

  void _checkRecordCallTrigger() {
    if (RecordCallTrigger.triggered) {
      RecordCallTrigger.triggered = false;
      _showRecordCallDialog();
    }
    Wav2Vec2ModelManager.ensureModel();
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
    final path = '${dir.path}/rec_${DateTime.now().millisecondsSinceEpoch}.m4a';
    _currentRecordingPath = path;
    try {
      await _audioRecorder.start(const RecordConfig(), path: path);
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
          ? (e.message ?? e.code ?? e.toString())
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
            const SizedBox(height: 32),
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
