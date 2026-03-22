import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/analysis_result.dart';
import '../models/history_record.dart';

/// Local history of analyzed recordings.
class HistoryService {
  HistoryService._();

  static final List<HistoryRecord> _records = [];
  static bool _loaded = false;

  static Future<List<HistoryRecord>> getAll() async {
    if (!_loaded) {
      await _load();
      _loaded = true;
    }
    return List.unmodifiable(_records);
  }

  static Future<void> add(HistoryRecord record) async {
    _records.insert(0, record);
    if (_records.length > 100) _records.removeRange(100, _records.length);
    await _save();
  }

  static Future<void> remove(String id) async {
    _records.removeWhere((r) => r.id == id);
    await _save();
  }

  static Future<void> clear() async {
    _records.clear();
    await _save();
  }

  static Future<File> get _file async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/history.json');
  }

  static Future<void> _load() async {
    try {
      final f = await _file;
      if (!await f.exists()) return;
      final raw = await f.readAsString();
      final list = jsonDecode(raw) as List<dynamic>?;
      if (list == null) return;
      _records.clear();
      for (final e in list) {
        final m = e as Map<String, dynamic>?;
        if (m == null) continue;
        final result = AnalysisResult(
          verdict: m['verdict'] as String? ?? 'suspicious',
          probability: (m['probability'] as num?)?.toDouble() ?? 0.0,
          source: m['source'] as String?,
          apiConfidenceLevel: m['apiConfidenceLevel'] as String?,
          modelVotes: _parseModelVotes(m['modelVotes']),
          analysisUrl: m['analysisUrl'] as String?,
        );
        _records.add(HistoryRecord(
          id: m['id'] as String? ?? '',
          audioPath: m['audioPath'] as String? ?? '',
          duration: m['duration'] as String? ?? '',
          result: result,
          createdAt: DateTime.tryParse(m['createdAt'] as String? ?? '') ?? DateTime.now(),
        ));
      }
    } catch (_) {}
  }

  static Future<void> _save() async {
    try {
      final f = await _file;
      await f.parent.create(recursive: true);
      await f.writeAsString(jsonEncode(_records.map((r) => {
            'id': r.id,
            'audioPath': r.audioPath,
            'duration': r.duration,
            'verdict': r.result.verdict,
            'probability': r.result.probability,
            'source': r.result.source,
            'apiConfidenceLevel': r.result.apiConfidenceLevel,
            'modelVotes': r.result.modelVotes,
            'analysisUrl': r.result.analysisUrl,
            'createdAt': r.createdAt.toIso8601String(),
          }).toList()));
    } catch (_) {}
  }

  static Map<String, double>? _parseModelVotes(dynamic raw) {
    if (raw is! Map) return null;
    final out = <String, double>{};
    for (final entry in raw.entries) {
      final key = entry.key.toString();
      final value = entry.value;
      if (value is num) {
        out[key] = value.toDouble();
      } else if (value is String) {
        final parsed = double.tryParse(value);
        if (parsed != null) out[key] = parsed;
      }
    }
    return out.isEmpty ? null : out;
  }
}
