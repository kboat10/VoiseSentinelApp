import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/analysis_result.dart';
import 'auth_storage.dart';

/// Backend API client for Voice Sentinel.
class ApiService {
  ApiService._();

  static const String _baseUrl = 'http://45.55.247.199/api';

  /// Upload audio file and get prediction.
  /// Uses stored user_id when logged in.
  /// Returns [AnalysisResult] or throws on error.
  static Future<AnalysisResult> predict(String audioPath, {int? userId}) async {
    final file = File(audioPath);
    if (!await file.exists()) {
      throw Exception('Audio file not found: $audioPath');
    }

    final uri = Uri.parse('$_baseUrl/forensics/predict');
    debugPrint('[ApiService] predict start uri=$uri audioPath=$audioPath');
    final request = http.MultipartRequest('POST', uri);
    request.files.add(
      await http.MultipartFile.fromPath('file', audioPath),
    );
    request.fields['user_id'] = (userId ?? AuthStorage.userId ?? 0).toString();

    final streamedResponse = await request.send()
        .timeout(const Duration(seconds: 60),
            onTimeout: () => throw TimeoutException('Upload timed out. Check your connection.'));
    final response = await http.Response.fromStream(streamedResponse);
    debugPrint('[ApiService] predict response status=${response.statusCode}');

    if (response.statusCode != 200) {
      throw Exception(
        'API error ${response.statusCode}: ${response.body}',
      );
    }

    final json = _parseJson(response.body);
    final syntheticProbability = _extractSyntheticProbability(json);
    final verdict = _verdictFromSyntheticProbability(syntheticProbability);

    final result = AnalysisResult(
      verdict: verdict,
      probability: syntheticProbability,
      sampleId: (json['sample_id'] as num?)?.toInt(),
      filename: json['filename'] as String?,
      source: 'online',
      apiConfidenceLevel: json['confidence_level'] as String?,
      modelVotes: _extractModelVotes(json['model_votes']),
      analysisUrl: json['analysis_url'] as String?,
    );
    debugPrint('[ApiService] predict normalized score=${result.sentinelScore} verdict=${result.canonicalVerdict} confidence=${result.confidenceScore} source=${result.source}');
    return result;
  }

  static double _extractSyntheticProbability(Map<String, dynamic> json) {
    final direct = _toDouble(json['synthetic_probability']) ??
        _toDouble(json['probability']) ??
        _toDouble(json['synthetic_prob']) ??
        _toDouble(json['p_synthetic']) ??
        _toDouble(json['score']);
    if (direct != null) return _clamp01(direct);

    final confidence = _toDouble(json['confidence_score']) ?? _toDouble(json['confidence']);
    if (confidence != null) {
      final verdictRaw = (json['verdict'] ?? '').toString().toLowerCase();
      final c = _clamp01(confidence);
      if (verdictRaw == 'real') return 1.0 - c;
      if (verdictRaw == 'synthetic' || verdictRaw == 'suspicious') return c;
      return c;
    }

    return 0.0;
  }

  static String _verdictFromSyntheticProbability(double pSynthetic) {
    return pSynthetic > 0.15 ? 'synthetic' : 'real';
  }

  static double _clamp01(double v) {
    if (v.isNaN || v.isInfinite) return 0.0;
    if (v < 0) return 0.0;
    if (v > 1) return 1.0;
    return v;
  }

  static double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static Map<String, double>? _extractModelVotes(dynamic raw) {
    if (raw is! Map) return null;
    final out = <String, double>{};
    for (final entry in raw.entries) {
      final key = entry.key.toString();
      final value = _toDouble(entry.value);
      if (value != null) out[key] = value;
    }
    return out.isEmpty ? null : out;
  }

  static Map<String, dynamic> _parseJson(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : {};
    } catch (_) {
      return {};
    }
  }
}
