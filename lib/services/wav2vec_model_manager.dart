import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'mobile_bundle_service.dart';

/// Manages Wav2Vec2 model: local path, download from API.
class Wav2Vec2ModelManager {
  Wav2Vec2ModelManager._();

  static String? _cachedModelPath;

  /// Path to local Wav2Vec2 ONNX model, or null if not available.
  static String? get modelPath => _cachedModelPath;

  /// Ensure model is available. Tries: cached path, existing file, API download.
  static Future<String?> ensureModel({
    void Function(int received, int total)? onDownloadProgress,
  }) async {
    if (_cachedModelPath != null) {
      final f = File(_cachedModelPath!);
      if (await f.exists()) return _cachedModelPath;
    }

    final dir = await getApplicationSupportDirectory();
    final localFile = File('${dir.path}/wav2vec2_quantized.onnx');
    if (await localFile.exists()) {
      _cachedModelPath = localFile.path;
      return _cachedModelPath;
    }

    try {
      final file = await MobileBundleService.downloadModel(
        onProgress: onDownloadProgress,
      );
      _cachedModelPath = file.path;
      return _cachedModelPath;
    } catch (_) {
      return null;
    }
  }

  static void clearCache() {
    _cachedModelPath = null;
  }
}
