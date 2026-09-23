import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'legacy_models.dart';

/// Keeps a bounded, device-local history of structured review checkpoints.
/// Source images are deliberately excluded; the checkpoint is useful for
/// recovery and audit without silently duplicating sensitive archive scans.
class SessionCheckpointStore {
  static const _key = 'legacylens_structured_checkpoints_v1';
  static const maxEntries = 20;

  Future<int> count() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key)?.length ?? 0;
  }

  Future<int> save(LegacyDocument document) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = prefs.getStringList(_key) ?? <String>[];
    final checkpoint = jsonEncode({
      'saved_at': DateTime.now().toIso8601String(),
      'source': document.name,
      'document_type': document.documentType,
      'page_count': document.pages.length,
      'quality': document.qualityReport,
      'structured_asset': jsonDecode(document.exportJson()),
      'source_images_retained': false,
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
