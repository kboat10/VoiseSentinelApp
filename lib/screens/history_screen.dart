import 'package:flutter/material.dart';

import '../models/analysis_result.dart';
import '../models/history_record.dart';
import '../theme/app_theme.dart';
import '../services/history_service.dart';
import 'audio_breakdown_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<HistoryRecord> _records = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final records = await HistoryService.getAll();
    if (mounted) {
      setState(() {
        _records = records;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.darkTextLight : AppTheme.darkText;
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _records.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history_rounded, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No recordings yet',
                        style: TextStyle(fontSize: 18, color: textColor),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Record a call to see analysis results here',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _records.length,
                    itemBuilder: (context, i) {
                      final r = _records[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _verdictColor(r.result).withValues(alpha: 0.2),
                            child: Icon(
                              r.result.isReal ? Icons.check_circle_rounded : Icons.warning_rounded,
                              color: _verdictColor(r.result),
                            ),
                          ),
                          title: Text(
                            _formatRecordTitle(r),
                            style: TextStyle(fontWeight: FontWeight.w600, color: textColor),
                          ),
                          subtitle: Text(
                            '${r.duration} • ${_verdictLabel(r.result)} • Sentinel ${(r.result.sentinelScore * 100).toStringAsFixed(0)}% • ${r.result.source ?? "unknown"}',
                            style: TextStyle(color: Colors.grey[600], fontSize: 13),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => AudioBreakdownScreen(result: r.result),
                              ),
                            );
                          },
                          onLongPress: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Delete'),
                                content: const Text('Remove this recording from history?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true && mounted) {
                              await HistoryService.remove(r.id);
                              _load();
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Color _verdictColor(AnalysisResult result) {
    switch (result.riskBand) {
      case 'safe':
        return Colors.green;
      case 'suspicious':
        return Colors.orange;
      case 'fake':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatRecordTitle(HistoryRecord r) {
    final d = r.createdAt;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final recordDay = DateTime(d.year, d.month, d.day);
    if (recordDay == today) {
      return 'Today ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }
    final yesterday = today.subtract(const Duration(days: 1));
    if (recordDay == yesterday) {
      return 'Yesterday ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }
    return '${d.month}/${d.day}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String _verdictLabel(AnalysisResult result) {
    switch (result.riskBand) {
      case 'safe':
        return 'Safe';
      case 'suspicious':
        return 'Suspicious';
      case 'fake':
        return 'Fake';
      default:
        return result.isSyntheticByRule ? 'Synthetic' : 'Real';
    }
  }
}
