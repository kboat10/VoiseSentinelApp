import 'package:flutter/material.dart';

import '../models/analysis_result.dart';
import '../theme/app_theme.dart';
import '../onnx/onnx_inference_service.dart';
import '../widgets/app_bar_back.dart';

class AudioBreakdownScreen extends StatelessWidget {
  const AudioBreakdownScreen({super.key, this.result});

  final AnalysisResult? result;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.darkTextLight : AppTheme.darkText;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: const AppBarBack(title: 'Analysis'),
      body: SafeArea(
        child: result == null
            ? _buildEmptyState(context, textColor)
            : _buildResultContent(context, result!, textColor, isDark),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, Color textColor) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'No analysis to show',
            style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Text(
            'Record a call and tap "Stop & Analyze" to see results here.',
            style: TextStyle(color: Colors.grey[700], fontSize: 15),
          ),
          const SizedBox(height: 32),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(Icons.analytics_outlined, size: 56, color: AppTheme.lightBlue),
                  const SizedBox(height: 16),
                  Text('No recording selected', style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text(
                    'Record a call from the Record tab to get started.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[700], fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultContent(BuildContext context, AnalysisResult r, Color textColor, bool isDark) {
    final verdictLabel = EnsembleVerdictLabels.labelFor(r.verdict);
    final verdictColor = _verdictColor(r.verdict);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: verdictColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      r.isReal ? Icons.check_circle_rounded : Icons.warning_rounded,
                      size: 48,
                      color: verdictColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    verdictLabel,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Confidence: ${(r.probability * 100).toStringAsFixed(1)}%',
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  ),
                  if (r.source != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      r.source == 'offline' ? 'Analyzed on-device' : 'Analyzed via API',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Classification thresholds',
            style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          _ThresholdRow('≤ 0.15', 'Real (Human)', Colors.green),
          _ThresholdRow('0.15 – 0.45', 'Suspicious', Colors.orange),
          _ThresholdRow('0.45 – 0.85', 'Synthetic (Probable)', Colors.deepOrange),
          _ThresholdRow('> 0.85', 'Synthetic (Definitive)', Colors.red),
        ],
      ),
    );
  }

  Color _verdictColor(String v) {
    switch (v) {
      case 'real':
        return Colors.green;
      case 'suspicious':
        return Colors.orange;
      case 'synthetic_probable':
      case 'synthetic_definitive':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

class _ThresholdRow extends StatelessWidget {
  const _ThresholdRow(this.range, this.label, this.color);

  final String range;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(range, style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
          ),
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
