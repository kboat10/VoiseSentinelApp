import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Mobile bundle API client for downloading Wav2Vec2 model and config.
class MobileBundleService {
  MobileBundleService._();

  static const String _baseUrl = 'http://45.55.247.199/api';

  /// Get bundle info (version, download URLs).
  static Future<BundleInfo> getBundleInfo() async {
    final res = await http.get(Uri.parse('$_baseUrl/mobile/bundle/info'));
    if (res.statusCode != 200) {
      throw Exception('Bundle info failed: ${res.statusCode}');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return BundleInfo.fromJson(json);
  }

  /// Download Wav2Vec2 ONNX model and save locally (~300MB).
  static Future<File> downloadModel({
    void Function(int received, int total)? onProgress,
  }) async {
    final req = http.Request('GET', Uri.parse('$_baseUrl/mobile/bundle/model'));
    final streamedRes = await http.Client().send(req);
    if (streamedRes.statusCode != 200) {
      throw Exception('Model download failed: ${streamedRes.statusCode}');
    }
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}/wav2vec2_quantized.onnx');
    final sink = file.openWrite();
    var received = 0;
    final total = streamedRes.contentLength ?? 0;
    await for (final chunk in streamedRes.stream) {
      sink.add(chunk);
      received += chunk.length;
      onProgress?.call(received, total > 0 ? total : received);
    }
    await sink.close();
    return file;
  }

  /// Download Wav2Vec2 config JSON.
  static Future<Map<String, dynamic>> getConfig() async {
    final res = await http.get(Uri.parse('$_baseUrl/mobile/bundle/config'));
    if (res.statusCode != 200) {
      throw Exception('Config download failed: ${res.statusCode}');
    }
    final json = jsonDecode(res.body);
    return json is Map ? Map<String, dynamic>.from(json) : {};
  }
}

class BundleInfo {
  BundleInfo({
    this.wav2vecModel,
    this.config,
    this.bundleVersion,
    this.endpoints,
  });

  final Map<String, dynamic>? wav2vecModel;
  final Map<String, dynamic>? config;
  final String? bundleVersion;
  final Map<String, dynamic>? endpoints;

  factory BundleInfo.fromJson(Map<String, dynamic> json) => BundleInfo(
        wav2vecModel: json['wav2vec_model'] as Map<String, dynamic>?,
        config: json['config'] as Map<String, dynamic>?,
        bundleVersion: json['bundle_version'] as String?,
        endpoints: json['endpoints'] as Map<String, dynamic>?,
      );
}
