/// Result of voice deepfake analysis.
class AnalysisResult {
  const AnalysisResult({
    required this.verdict,
    required this.probability,
    this.sampleId,
    this.filename,
    this.source,
  });

  /// Verdict: real, suspicious, synthetic_probable, synthetic_definitive
  final String verdict;

  /// Probability of synthetic (0.0 = real, 1.0 = synthetic)
  final double probability;

  /// Sample ID from backend (when analyzed via API)
  final int? sampleId;

  /// Original filename
  final String? filename;

  /// 'online' or 'offline'
  final String? source;

  bool get isReal => verdict == 'real';
  bool get isSynthetic =>
      verdict == 'synthetic_probable' || verdict == 'synthetic_definitive';
}
