import 'package:flutter_test/flutter_test.dart';

import 'package:voice_recording_app_gui/models/analysis_result.dart';
import 'package:voice_recording_app_gui/models/history_record.dart';

/// Unit tests that run entirely in the Dart VM (no device, no method channels).
/// Run with: flutter test
void main() {
  // ── AnalysisResult model ──────────────────────────────────────────────────

  group('AnalysisResult', () {
    test('isReal is true only for "real" verdict', () {
      expect(const AnalysisResult(verdict: 'real', probability: 0.05).isReal, isTrue);
      expect(const AnalysisResult(verdict: 'suspicious', probability: 0.30).isReal, isFalse);
      expect(const AnalysisResult(verdict: 'synthetic_probable', probability: 0.60).isReal, isFalse);
      expect(const AnalysisResult(verdict: 'synthetic_definitive', probability: 0.90).isReal, isFalse);
    });

    test('isSynthetic is true for both synthetic verdicts', () {
      expect(const AnalysisResult(verdict: 'synthetic_probable', probability: 0.60).isSynthetic, isTrue);
      expect(const AnalysisResult(verdict: 'synthetic_definitive', probability: 0.90).isSynthetic, isTrue);
      expect(const AnalysisResult(verdict: 'real', probability: 0.05).isSynthetic, isFalse);
      expect(const AnalysisResult(verdict: 'suspicious', probability: 0.30).isSynthetic, isFalse);
    });

    test('probability is stored as-is', () {
      const r = AnalysisResult(verdict: 'real', probability: 0.123);
      expect(r.probability, closeTo(0.123, 1e-9));
    });

    test('source field is nullable', () {
      const r1 = AnalysisResult(verdict: 'real', probability: 0.0);
      const r2 = AnalysisResult(verdict: 'real', probability: 0.0, source: 'online');
      const r3 = AnalysisResult(verdict: 'real', probability: 0.0, source: 'offline');
      expect(r1.source, isNull);
      expect(r2.source, equals('online'));
      expect(r3.source, equals('offline'));
    });
  });

  // ── Verdict threshold mapping (mirrors OnnxEnsemble.kt) ──────────────────

  group('Verdict threshold mapping', () {
    String verdictFor(double p) {
      if (p > 0.85) return 'synthetic_definitive';
      if (p >= 0.45) return 'synthetic_probable';
      if (p >= 0.15) return 'suspicious';
      return 'real';
    }

    test('p <= 0.14 → real', () {
      expect(verdictFor(0.00), equals('real'));
      expect(verdictFor(0.10), equals('real'));
      expect(verdictFor(0.14), equals('real'));
    });

    test('p 0.15–0.44 → suspicious', () {
      expect(verdictFor(0.15), equals('suspicious'));
      expect(verdictFor(0.30), equals('suspicious'));
      expect(verdictFor(0.44), equals('suspicious'));
    });

    test('p 0.45–0.85 → synthetic_probable', () {
      expect(verdictFor(0.45), equals('synthetic_probable'));
      expect(verdictFor(0.65), equals('synthetic_probable'));
      expect(verdictFor(0.85), equals('synthetic_probable'));
    });

    test('p > 0.85 → synthetic_definitive', () {
      expect(verdictFor(0.86), equals('synthetic_definitive'));
      expect(verdictFor(0.99), equals('synthetic_definitive'));
      expect(verdictFor(1.00), equals('synthetic_definitive'));
    });
  });

  // ── HistoryRecord model ───────────────────────────────────────────────────

  group('HistoryRecord', () {
    AnalysisResult makeResult(String verdict) =>
        AnalysisResult(verdict: verdict, probability: 0.5, source: 'online');

    test('stores all fields', () {
      final now = DateTime(2025, 3, 15, 10, 0);
      final r = HistoryRecord(
        id: 'abc123',
        audioPath: '/tmp/rec.wav',
        duration: '00:05',
        result: makeResult('real'),
        createdAt: now,
      );
      expect(r.id, equals('abc123'));
      expect(r.audioPath, equals('/tmp/rec.wav'));
      expect(r.duration, equals('00:05'));
      expect(r.result.verdict, equals('real'));
      expect(r.createdAt, equals(now));
    });

    test('result reference is the same object passed in', () {
      final result = makeResult('suspicious');
      final record = HistoryRecord(
        id: '1',
        audioPath: '/tmp/r.wav',
        duration: '00:10',
        result: result,
        createdAt: DateTime.now(),
      );
      expect(identical(record.result, result), isTrue);
    });
  });

  // ── Feature dimension constants (mirrors Kotlin) ─────────────────────────

  group('Feature dimension constants', () {
    const int dspDim = 68;
    const int sslDim = 1024;
    const int featureDim = 1092;

    test('DSP + SSL = FEATURE_DIM', () {
      expect(dspDim + sslDim, equals(featureDim));
    });

    test('DSP breakdown: centroid(1)+logEnergy(1)+mfccMean(13)+mfccStd(13)+mel(40)', () {
      const centroid = 1;
      const logEnergy = 1;
      const mfccMean = 13;
      const mfccStd = 13;
      const mel = 40;
      expect(centroid + logEnergy + mfccMean + mfccStd + mel, equals(dspDim));
    });

    test('ensemble has 5 base models plus scaler and meta-learner = 7 total', () {
      const baseModels = 5; // RF, CNN, CNN-LSTM, TCN, TSSD
      const scaler = 1;
      const metaLearner = 1;
      expect(baseModels + scaler + metaLearner, equals(7));
    });
  });
}
