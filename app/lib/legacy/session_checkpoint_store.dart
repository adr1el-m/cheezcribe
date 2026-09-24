import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'legacy_models.dart';

class SessionCheckpoint {
  const SessionCheckpoint({
    required this.savedAt,
    required this.source,
    required this.documentType,
    required this.pageCount,
    required this.fieldCount,
    required this.needsReview,
    this.sourcePath,
  });

  final DateTime savedAt;
  final String source;
  final String documentType;
  final int pageCount;
  final int fieldCount;
  final int needsReview;
  final String? sourcePath;

  bool get canReopen => sourcePath != null && sourcePath!.isNotEmpty;

  factory SessionCheckpoint.fromJson(Map<String, dynamic> json) =>
      SessionCheckpoint(
        savedAt: DateTime.tryParse(json['saved_at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        source: json['source'] as String? ?? 'Imported document',
        documentType: json['document_type'] as String? ?? 'Legacy record',
        pageCount: (json['page_count'] as num?)?.toInt() ?? 0,
        fieldCount: (json['field_count'] as num?)?.toInt() ?? 0,
        needsReview: (json['needs_review'] as num?)?.toInt() ?? 0,
        sourcePath: json['source_path'] as String?,
      );
}

/// Keeps a bounded, device-local history of structured review checkpoints.
/// Source images are deliberately excluded; the checkpoint is useful for
/// recovery and audit without silently duplicating sensitive archive scans.
class SessionCheckpointStore {
  static const _key = 'paperazzi_checkpoint_summaries_v2';
  static const _legacyKey = 'legacylens_structured_checkpoints_v1';
  static const maxEntries = 12;

  Future<SharedPreferences> _preferences() async {
    final prefs = await SharedPreferences.getInstance();
    // Older builds wrote the entire export into NSUserDefaults. Large scans
    // could exceed several megabytes and stall the UI on every edit.
    if (prefs.containsKey(_legacyKey)) await prefs.remove(_legacyKey);
    return prefs;
  }

  Future<int> count() async {
    final prefs = await _preferences();
    return prefs.getStringList(_key)?.length ?? 0;
  }

  Future<List<SessionCheckpoint>> list() async {
    final prefs = await _preferences();
    final entries = prefs.getStringList(_key) ?? const <String>[];
    return [
      for (final entry in entries) tryParse(entry),
    ].whereType<SessionCheckpoint>().toList();
  }

  SessionCheckpoint? tryParse(String entry) {
    try {
      return SessionCheckpoint.fromJson(
          Map<String, dynamic>.from(jsonDecode(entry) as Map));
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    final prefs = await _preferences();
    await prefs.remove(_key);
  }

  Future<int> save(LegacyDocument document) async {
    final prefs = await _preferences();
    final entries = prefs.getStringList(_key) ?? <String>[];
    // Checkpoints are intentionally compact summaries. Full reviewed data is
    // exported explicitly and never stored in preferences.
    final checkpoint = jsonEncode({
      'saved_at': DateTime.now().toIso8601String(),
      'source': document.name,
      'document_type': document.documentType,
      'page_count': document.pages.length,
      'field_count': document.fields.length,
      'needs_review': document.needsReview,
      'resolved': document.resolved,
      'mean_ocr_confidence': document.meanOcrConfidence,
      'source_images_retained': false,
      'structured_asset_retained': false,
      'source_path': document.sourcePath,
    });
    entries.removeWhere((entry) {
      try {
        return (jsonDecode(entry) as Map<String, dynamic>)['source'] ==
            document.name;
      } catch (_) {
        return true;
      }
    });
    entries.insert(0, checkpoint);
    if (entries.length > maxEntries) {
      entries.removeRange(maxEntries, entries.length);
    }
    await prefs.setStringList(_key, entries);
    return entries.length;
  }
}
