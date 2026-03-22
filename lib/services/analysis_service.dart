import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/analysis_result.dart';
import '../onnx/onnx_inference_service.dart';
import 'api_service.dart';
import 'inference_mode_service.dart';
import 'wav2vec_model_manager.dart';

/// Dual-path analysis: online (API) or offline (on-device ONNX).
class AnalysisService {
  AnalysisService._();

  /// Analyzes audio file. Uses API when online, on-device when offline.
  static Future<AnalysisResult> analyze(String audioPath) async {
    final mode = await InferenceModeService.getMode();
    final hasConnection = await _hasConnection();
    debugPrint('[AnalysisService] analyze start mode=${mode.name} hasConnection=$hasConnection path=$audioPath');

    if (mode == InferenceMode.onlineOnly) {
      debugPrint('[AnalysisService] route=ONLINE (forced by settings)');
      return ApiService.predict(audioPath);
    }

    if (mode == InferenceMode.offlineOnly) {
      debugPrint('[AnalysisService] route=OFFLINE (forced by settings)');
      return _analyzeOffline(audioPath);
    }

    if (hasConnection) {
      try {
        debugPrint('[AnalysisService] route=ONLINE (API)');
        final onlineResult = await ApiService.predict(audioPath);
        debugPrint('[AnalysisService] online result source=${onlineResult.source} verdict=${onlineResult.canonicalVerdict} score=${onlineResult.sentinelScore} confidence=${onlineResult.confidenceScore}');
        return onlineResult;
      } catch (apiError) {
        debugPrint('[AnalysisService] online failed error=$apiError');
        // Fall back to offline only if the model is ready; otherwise surface the API error
        if (Wav2Vec2ModelManager.instance.isReady) {
          debugPrint('[AnalysisService] fallback route=OFFLINE (model ready)');
          return await _analyzeOffline(audioPath);
        }
        debugPrint('[AnalysisService] fallback unavailable modelReady=false, rethrowing');
        rethrow;
      }
    } else {
      debugPrint('[AnalysisService] route=OFFLINE (no connection)');
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

    final manager = Wav2Vec2ModelManager.instance;
    // Fail fast — do NOT wait for a potentially 300MB download during analysis
    if (!manager.isReady) {
      final status = manager.status;
      if (status == ModelStatus.downloading || status == ModelStatus.checking) {
        throw PlatformException(
          code: 'MODEL_NOT_READY',
          message: 'Offline model is still downloading. Please wait and try again.',
        );
      }
      throw PlatformException(
        code: 'MODEL_NOT_READY',
        message: 'Offline model is not available. Please check your connection and try again.',
      );
    }

    final modelPath = manager.modelPath;
    debugPrint('[AnalysisService] offline start modelPath=${modelPath ?? 'null'}');
    final features = await OnnxInferenceService.extractFeaturesFromAudio(
      audioPath,
      wav2vecModelPath: modelPath,
    );
    debugPrint('[AnalysisService] offline extracted features=${features.length}');
    await OnnxInferenceService.loadEnsembleModels();
    debugPrint('[AnalysisService] offline ensemble models loaded');
    final result = await OnnxInferenceService.runEnsemble(features);
    debugPrint('[AnalysisService] offline result rawVerdict=${result.verdict} score=${result.probability}');

    return AnalysisResult(
      verdict: result.probability > 0.15 ? 'synthetic' : 'real',
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
