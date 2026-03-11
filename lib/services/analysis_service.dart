import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';

import '../models/analysis_result.dart';
import '../onnx/onnx_inference_service.dart';
import 'api_service.dart';
import 'wav2vec_model_manager.dart';

/// Dual-path analysis: online (API) or offline (on-device ONNX).
class AnalysisService {
  AnalysisService._();

  /// Analyzes audio file. Uses API when online, on-device when offline.
  static Future<AnalysisResult> analyze(String audioPath) async {
    final hasConnection = await _hasConnection();

    if (hasConnection) {
      try {
        return await ApiService.predict(audioPath);
      } catch (_) {
        // Fall back to offline if API fails
        return await _analyzeOffline(audioPath);
      }
    } else {
      return await _analyzeOffline(audioPath);
    }
  }

  static Future<AnalysisResult> _analyzeOffline(String audioPath) async {
    if (!Platform.isAndroid) {
      throw PlatformException(
        code: 'OFFLINE_UNSUPPORTED',
        message: 'Offline analysis is only supported on Android',
      );
    }

    final modelPath = await Wav2Vec2ModelManager.ensureModel();
    final features = await OnnxInferenceService.extractFeaturesFromAudio(
      audioPath,
      wav2vecModelPath: modelPath,
    );
    await OnnxInferenceService.loadEnsembleModels();
    final result = await OnnxInferenceService.runEnsemble(features);

    return AnalysisResult(
      verdict: result.verdict,
      probability: result.probability,
      source: 'offline',
    );
  }

  static Future<bool> _hasConnection() async {
    final result = await Connectivity().checkConnectivity();
    return result.any((c) =>
        c == ConnectivityResult.wifi ||
        c == ConnectivityResult.mobile ||
        c == ConnectivityResult.ethernet);
  }

  /// Stream of connectivity changes (for upload queue).
  static Stream<List<ConnectivityResult>> get connectivityStream =>
      Connectivity().onConnectivityChanged;
}
