import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'mobile_bundle_service.dart';

enum ModelStatus { idle, checking, downloading, ready, error }

/// Singleton that manages the Wav2Vec2 ONNX model lifecycle.
/// Notifies listeners on status/progress changes.
class Wav2Vec2ModelManager extends ChangeNotifier {
  Wav2Vec2ModelManager._();
  static final Wav2Vec2ModelManager instance = Wav2Vec2ModelManager._();

  String? _modelPath;
  ModelStatus _status = ModelStatus.idle;
  double _downloadProgress = 0.0;
  String? _errorMessage;

  String? get modelPath => _modelPath;
  ModelStatus get status => _status;
  double get downloadProgress => _downloadProgress;
  String? get errorMessage => _errorMessage;

  bool get isReady => _status == ModelStatus.ready;
  bool get isDownloading => _status == ModelStatus.downloading;

  /// Call once on app startup. Safe to call multiple times (idempotent).
  Future<void> ensureModel() async {
    if (_status == ModelStatus.ready ||
        _status == ModelStatus.downloading ||
        _status == ModelStatus.checking) {
      return;
    }

    _status = ModelStatus.checking;
    _errorMessage = null;
    notifyListeners();

    try {
      // Check cached path (also verify size)
      const int minModelBytes = 10 * 1024 * 1024; // 10 MB
      if (_modelPath != null) {
        final cachedFile = File(_modelPath!);
        if (await cachedFile.exists() && await cachedFile.length() >= minModelBytes) {
          _status = ModelStatus.ready;
          notifyListeners();
          return;
        }
        _modelPath = null; // stale/corrupt cache
      }

      // Check persisted file (must be >= 10 MB to reject partial/corrupt downloads)
      final dir = await getApplicationSupportDirectory();
      final localFile = File('${dir.path}/wav2vec2_quantized.onnx');
      if (await localFile.exists()) {
        final size = await localFile.length();
        if (size >= minModelBytes) {
          _modelPath = localFile.path;
          _status = ModelStatus.ready;
          notifyListeners();
          return;
        }
        // Corrupt/partial — delete and re-download
        await localFile.delete();
      }

      // Download
      _status = ModelStatus.downloading;
      _downloadProgress = 0.0;
      notifyListeners();

      final file = await MobileBundleService.downloadModel(
        onProgress: (received, total) {
          if (total > 0) {
            _downloadProgress = received / total;
            notifyListeners();
          }
        },
      );
      _modelPath = file.path;
      _status = ModelStatus.ready;
      _downloadProgress = 1.0;
      notifyListeners();
    } catch (e) {
      _status = ModelStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Retry after an error.
  Future<void> retry() async {
    if (_status == ModelStatus.error || _status == ModelStatus.idle) {
      _status = ModelStatus.idle;
      notifyListeners();
      await ensureModel();
    }
  }

  /// Returns model path when ready. Triggers download if needed and awaits completion.
  Future<String?> getModelPath() async {
    if (_status == ModelStatus.ready) return _modelPath;
    if (_status == ModelStatus.idle) {
      ensureModel(); // fire — do not await so caller can observe progress
    }
    if (_status == ModelStatus.checking || _status == ModelStatus.downloading) {
      final completer = Completer<String?>();
      void listener() {
        if (_status == ModelStatus.ready) {
          if (!completer.isCompleted) completer.complete(_modelPath);
          removeListener(listener);
        } else if (_status == ModelStatus.error) {
          if (!completer.isCompleted) completer.complete(null);
          removeListener(listener);
        }
      }
      addListener(listener);
      return completer.future;
    }
    return null;
  }

  void clearCache() {
    _modelPath = null;
    if (_status == ModelStatus.ready) {
      _status = ModelStatus.idle;
      notifyListeners();
    }
  }
}
