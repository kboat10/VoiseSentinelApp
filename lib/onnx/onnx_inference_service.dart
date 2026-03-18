import 'dart:async';
import 'package:flutter/services.dart';

/// Calls ONNX Runtime on Android via method channel.
/// Supports single-model inference and full stacked-ensemble pipeline.
class OnnxInferenceService {
  OnnxInferenceService._();
  static const MethodChannel _channel =
      MethodChannel('com.example.voice_recording_app_gui/onnx');

  /// Returns true if app was opened from "record call" notification. Clears the flag.
  static Future<bool> getAndClearRecordCallIntent() async {
    final result = await _channel.invokeMethod<bool>('getAndClearRecordCallIntent');
    return result == true;
  }

  /// Extracts 1092-dim feature vector from audio file (for offline inference).
  /// Decodes audio, extracts DSP + Wav2Vec2 features on Android.
  /// [wav2vecModelPath] optional path to downloaded Wav2Vec2 ONNX (from /mobile/bundle/model).
  static Future<List<double>> extractFeaturesFromAudio(
    String audioPath, {
    String? wav2vecModelPath,
  }) async {
    final result = await _channel.invokeMethod<List<Object?>>(
      'extractFeaturesFromAudio',
      {
        'audioPath': audioPath,
        if (wav2vecModelPath != null) 'wav2vecModelPath': wav2vecModelPath,
      },
    );
    if (result == null) throw Exception('extractFeaturesFromAudio returned null');
    return result.map((e) => (e is num) ? e.toDouble() : 0.0).toList();
  }

  /// Loads all 7 ensemble models (scaler + 5 base + meta_learner). Call once before [runEnsemble].
  static Future<void> loadEnsembleModels() async {
    await _channel.invokeMethod<void>('loadEnsembleModels');
  }

  /// Runs the full Serial-Parallel-Serial ensemble pipeline.
  /// [features] must be the 1092-dim vector (centroid_mean, log_energy, mfcc_1..13, mfcc_std_1..13, mel_1..40, ssl_0..1023).
  /// Returns [EnsembleResult] with probability and verdict (real / suspicious / synthetic_probable / synthetic_definitive).
  static Future<EnsembleResult> runEnsemble(List<double> features) async {
    if (features.length != 1092) {
      throw ArgumentError('Expected 1092 features, got ${features.length}');
    }
    final result = await _channel.invokeMethod<Map<Object?, Object?>>(
      'runEnsemble',
      {'features': features},
    );
    if (result == null) throw Exception('runEnsemble returned null');
    final prob = result['probability'];
    final probability = (prob is num) ? prob.toDouble() : 0.0;
    final verdict = (result['verdict'] as String?) ?? 'suspicious';
    return EnsembleResult(probability: probability, verdict: verdict);
  }

  /// Loads a single model from assets.
  /// [assetPath] e.g. "models/onnx_models/ensemble.onnx"
  static Future<void> loadModel(String assetPath) async {
    await _channel.invokeMethod<void>('loadModel', {'assetPath': assetPath});
  }

  /// Runs inference. Call [loadModel] first for this [modelAssetPath].
  /// [inputShape] e.g. [1, 80, 100] for (batch, features, time).
  /// [inputValues] flat list of floats in row-major order.
  /// Returns map of output name -> list of float values (e.g. {"output": [0.2, 0.8]}).
  static Future<Map<String, List<double>>> runInference({
    required String modelAssetPath,
    required List<int> inputShape,
    required List<double> inputValues,
  }) async {
    final result = await _channel.invokeMethod<Map<Object?, Object?>>(
      'runInference',
      {
        'modelAssetPath': modelAssetPath,
        'inputShape': inputShape,
        'inputValues': inputValues,
      },
    );
    if (result == null) throw Exception('Inference returned null');
    final out = <String, List<double>>{};
    for (final entry in result.entries) {
      final key = entry.key as String;
      final value = entry.value as List<Object?>;
      out[key] = value.map((e) => (e as num).toDouble()).toList();
    }
    return out;
  }

  /// Unloads a model to free memory.
  static Future<void> unloadModel(String modelAssetPath) async {
    await _channel.invokeMethod<void>('unloadModel', {
      'modelAssetPath': modelAssetPath,
    });
  }
}

/// Result of the stacked-ensemble pipeline.
class EnsembleResult {
  const EnsembleResult({required this.probability, required this.verdict});

  /// Final forensic score P(synthetic), 0.0 = real, 1.0 = synthetic.
  final double probability;

  /// One of: real, suspicious, synthetic_probable, synthetic_definitive.
  final String verdict;
}

/// Verdict keys returned by the ensemble (hardened thresholds).
abstract class EnsembleVerdict {
  static const String real = 'real';
  static const String suspicious = 'suspicious';
  static const String syntheticProbable = 'synthetic_probable';
  static const String syntheticDefinitive = 'synthetic_definitive';
}

/// Human-readable labels and semantics for UI.
abstract class EnsembleVerdictLabels {
  static const String real = 'Real (Authentic Human)';
  static const String suspicious = 'Suspicious (Inconclusive)';
  static const String syntheticProbable = 'Synthetic (Probable AI)';
  static const String syntheticDefinitive = 'Synthetic (Definitive AI)';

  static String labelFor(String verdict) {
    switch (verdict) {
      case EnsembleVerdict.real:
        return real;
      case EnsembleVerdict.suspicious:
        return suspicious;
      case EnsembleVerdict.syntheticProbable:
        return syntheticProbable;
      case EnsembleVerdict.syntheticDefinitive:
        return syntheticDefinitive;
      default:
        return verdict;
    }
  }
}
