/// Result of voice deepfake analysis.
class AnalysisResult {
  const AnalysisResult({
    required this.verdict,
    required this.probability,
    this.sampleId,
    this.filename,
    this.source,
    this.apiConfidenceLevel,
    this.modelVotes,
    this.analysisUrl,
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

  /// Optional confidence level returned by backend API.
  final String? apiConfidenceLevel;

  /// Optional per-model vote/confidence map returned by backend API.
  final Map<String, double>? modelVotes;

  /// Optional backend analysis URL.
  final String? analysisUrl;

  /// Raw model/API probability of synthetic speech, clamped to [0, 1].
  double get syntheticProbability {
    if (probability.isNaN || probability.isInfinite) return 0.0;
    if (probability < 0) return 0.0;
    if (probability > 1) return 1.0;
    return probability;
  }

  /// Decision boundary from web backend: synthetic if > 0.15, real otherwise.
  bool get isSyntheticByRule => syntheticProbability > 0.15;
  bool get isRealByRule => !isSyntheticByRule;

  /// Canonical verdict used in UI and reporting.
  String get canonicalVerdict => isSyntheticByRule ? 'synthetic' : 'real';

  /// Confidence in the chosen verdict.
  /// Synthetic verdict -> confidence = P(synthetic)
  /// Real verdict -> confidence = 1 - P(synthetic)
  double get confidenceScore =>
      isSyntheticByRule ? syntheticProbability : (1.0 - syntheticProbability);

  /// Sentinel Score is confidence in the selected verdict (Real/Fake).
  double get sentinelScore => confidenceScore;

  /// Three-level UI risk band for color-coding.
  String get riskBand {
    final p = syntheticProbability;
    if (p <= 0.15) return 'safe';
    if (p <= 0.45) return 'suspicious';
    return 'fake';
  }

  /// Confidence level mapping from web backend rules.
  /// >0.85 => High, >0.45 => Medium, >0.15 => Low, <=0.15 => High (confident real)
  String get confidenceLevel {
    final s = syntheticProbability;
    if (s > 0.85) return 'High';
    if (s > 0.45) return 'Medium';
    if (s > 0.15) return 'Low/Suspicious';
    return 'High';
  }

  bool get isReal => isRealByRule;
  bool get isSynthetic => isSyntheticByRule;
}
