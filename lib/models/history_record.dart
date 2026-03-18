import 'analysis_result.dart';

/// A recording with its analysis result for history display.
class HistoryRecord {
  const HistoryRecord({
    required this.id,
    required this.audioPath,
    required this.duration,
    required this.result,
    required this.createdAt,
  });

  final String id;
  final String audioPath;
  final String duration;
  final AnalysisResult result;
  final DateTime createdAt;
}
