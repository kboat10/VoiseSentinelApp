import 'dart:async';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../theme/app_theme.dart';
import 'welcome_screen.dart';
import '../widgets/gradient_button.dart';
import '../widgets/live_voice_waveform.dart' show LiveVoiceWaveform, AudioVisualizerStyle;
import '../widgets/themed_scaffold.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<_Recording> _recordings = [];
  bool _isRecording = false;
  int _recordingSeconds = 0;
  Timer? _timer;
  final AudioRecorder _audioRecorder = AudioRecorder();
  final List<double> _amplitudeHistory = [];
  static const int _maxAmplitudeBars = 40;
  StreamSubscription<Amplitude>? _amplitudeSub;

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
    try {
      await _audioRecorder.start(const RecordConfig(), path: path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not start recording: $e')),
      );
      return;
    }
    _amplitudeHistory.clear();
    _amplitudeSub = _audioRecorder
        .onAmplitudeChanged(const Duration(milliseconds: 40))
        .listen((Amplitude amp) {
      // dBFS: -90 (silence) to 0 (max). Map so speech produces clear visual movement.
      final db = amp.current.clamp(-90.0, 0.0);
      final normalized = (db + 90) / 90;
      // Slightly more gain so speaking clearly moves the visualizer (0.2 baseline, 0.8 range).
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
    try {
      await _audioRecorder.stop();
    } catch (_) {}
    _timer?.cancel();
    _timer = null;
    final duration = _formatDuration(_recordingSeconds);
    setState(() {
      _isRecording = false;
      _recordings.insert(
        0,
        _Recording(
          name: 'Recording ${_recordings.length + 1}',
          duration: duration,
          status: _RecordStatus.analyzing,
        ),
      );
      _recordingSeconds = 0;
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        final idx = _recordings.indexWhere((r) => r.status == _RecordStatus.analyzing);
        if (idx >= 0) {
          _recordings[idx] = _Recording(
            name: _recordings[idx].name,
            duration: _recordings[idx].duration,
            status: _RecordStatus.completed,
          );
        }
      });
    });
  }

  void _deleteRecording(int index) {
    setState(() => _recordings.removeAt(index));
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
    return ThemedScaffold(
      drawer: _buildDrawer(context, textColor),
      appBar: AppBar(
        title: const Text('Voice Sentinel'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => Navigator.of(context).pushNamed('/settings'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Deepfake Detection',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                color: isDark ? AppTheme.darkTextLight : const Color(0xFF1F2937),
                letterSpacing: -0.5,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Protecting your audio authenticity with AI.',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.normal,
                color: isDark ? Colors.grey[400] : const Color(0xFF6B7280),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),
            _buildRecordCard(context, textColor),
            const SizedBox(height: 20),
            _buildAudioPreviewSection(context, textColor),
            const SizedBox(height: 16),
            _buildUploadCard(context, textColor),
            const SizedBox(height: 24),
            _buildRecordingsSection(context, textColor),
            const SizedBox(height: 32),
            GradientButton(
              label: _isRecording ? 'Stop Recording' : 'Analyze Audio',
              onPressed: _isRecording ? _stopRecording : _startRecording,
              expand: true,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {},
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
              child: const Text(
                'View History',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Drawer _buildDrawer(BuildContext context, Color textColor) {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Text(
                'Voice Sentinel',
                style: TextStyle(
                  color: textColor,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.person_outline_rounded, color: AppTheme.primaryBlue),
              title: Text('Change user type', style: TextStyle(color: textColor, fontWeight: FontWeight.w500)),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/change-user-type');
              },
            ),
            ListTile(
              leading: const Icon(Icons.analytics_outlined, color: AppTheme.primaryBlue),
              title: Text('Audio breakdown', style: TextStyle(color: textColor, fontWeight: FontWeight.w500)),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/audio-breakdown');
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: AppTheme.primaryBlue),
              title: Text('Log out', style: TextStyle(color: textColor, fontWeight: FontWeight.w500)),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                  (route) => false,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordCard(BuildContext context, Color textColor) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.lightBlue.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.mic_none_rounded,
                color: AppTheme.lightBlue,
                size: 32,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isRecording ? 'Recording...' : 'Ready to Scan',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isRecording
                        ? _formatDuration(_recordingSeconds)
                        : 'Record or upload an audio file to begin.',
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioPreviewSection(BuildContext context, Color textColor) {
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
                  'Tap "Analyze Audio" to record and see the waveform',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadCard(BuildContext context, Color textColor) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          setState(() {
            _recordings.insert(
              0,
              _Recording(
                name: 'Uploaded audio',
                duration: '--:--',
                status: _RecordStatus.analyzing,
              ),
            );
          });
          Future.delayed(const Duration(seconds: 2), () {
            if (!mounted) return;
            setState(() {
              final idx = _recordings.indexWhere(
                  (r) => r.name == 'Uploaded audio' && r.status == _RecordStatus.analyzing);
              if (idx >= 0) {
                _recordings[idx] = _Recording(
                  name: _recordings[idx].name,
                  duration: _recordings[idx].duration,
                  status: _RecordStatus.completed,
                );
              }
            });
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.lightBlue.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.upload_rounded,
                  color: AppTheme.lightBlue,
                  size: 32,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Upload Audio',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap to upload from your device.',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecordingsSection(BuildContext context, Color textColor) {
    if (_recordings.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Recordings',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        const SizedBox(height: 12),
        ...List.generate(
          _recordings.length,
          (i) => _buildRecordingTile(context, i, textColor),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildRecordingTile(BuildContext context, int index, Color textColor) {
    final r = _recordings[index];
    return Card(
      margin: EdgeInsets.only(bottom: index < _recordings.length - 1 ? 8 : 0),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.lightBlue.withValues(alpha: 0.15),
          child: r.status == _RecordStatus.analyzing
              ? Padding(
                  padding: const EdgeInsets.all(8),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.primaryBlue,
                  ),
                )
              : Icon(
                  r.status == _RecordStatus.completed
                      ? Icons.check_circle_rounded
                      : Icons.mic_rounded,
                  color: AppTheme.lightBlue,
                  size: 24,
                ),
        ),
        title: Text(r.name, style: TextStyle(fontWeight: FontWeight.w600, color: textColor)),
        subtitle: Text(r.duration, style: TextStyle(color: Colors.grey[700])),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline_rounded, color: Colors.grey[700]),
          onPressed: () => _deleteRecording(index),
        ),
      ),
    );
  }
}

class _Recording {
  _Recording({required this.name, required this.duration, required this.status});

  final String name;
  final String duration;
  final _RecordStatus status;
}

enum _RecordStatus { analyzing, completed }
