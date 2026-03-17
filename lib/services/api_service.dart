import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
    final request = http.MultipartRequest('POST', uri);
    request.files.add(
      await http.MultipartFile.fromPath('file', audioPath),
    );
    request.fields['user_id'] = (userId ?? AuthStorage.userId ?? 0).toString();

    final streamedResponse = await request.send()
        .timeout(const Duration(seconds: 60),
            onTimeout: () => throw TimeoutException('Upload timed out. Check your connection.'));
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw Exception(
        'API error ${response.statusCode}: ${response.body}',
      );
    }

    final json = _parseJson(response.body);
    final verdict = _mapVerdict(json['verdict']);
    final confidence = (json['confidence'] as num?)?.toDouble() ??
        (json['confidence_score'] as num?)?.toDouble() ??
        0.0;

    return AnalysisResult(
      verdict: verdict,
      probability: confidence,
      sampleId: (json['sample_id'] as num?)?.toInt(),
      filename: json['filename'] as String?,
      source: 'online',
    );
  }

  static String _mapVerdict(dynamic v) {
    if (v == null) return 'suspicious';
    final s = v.toString().toLowerCase();
    if (s == 'real') return 'real';
    if (s == 'synthetic') return 'synthetic_probable';
    return s;
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
