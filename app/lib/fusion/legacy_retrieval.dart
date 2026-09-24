import 'dart:math' as math;

import 'fusion_models.dart';
import 'knowledge_index.dart';

/// Ranks archive passages (structured fields and OCR lines) for a query.
class LegacyRetrieval {
  const LegacyRetrieval({this.limit = 10});
  final int limit;

  List<LegacyEvidence> search(FusionQuery query, List<IndexedDocument> docs) {
    if (query.terms.isEmpty || docs.isEmpty) return const [];

    final units = <_Unit>[];
    for (final doc in docs) {
      for (final f in doc.fields) {
        units.add(_Unit(doc, '${_label(f.name)}: ${f.value}', f.page, f.line,
            field: _label(f.name), record: f.record, verified: f.verified));
      }
      for (final l in doc.lines) {
        units.add(_Unit(doc, l.text, l.page, l.line,
            confidence: l.confidence, box: l.box));
      }
    }

    // Inverse document frequency over passages, so rare asset names outrank
    // common words like "pump".
    final df = <String, int>{};
    for (final term in query.terms) {
      df[term] = units.where((u) => u.lower.contains(term)).length;
    }
    double idf(String term) =>
        math.log((units.length + 1) / ((df[term] ?? 0) + 1)) + 1;

    final entityTerms = query.entities.map((e) => e.toLowerCase()).toSet();
    final scored = <(_Unit, double)>[];
    for (final u in units) {
      var score = 0.0;
      var hits = 0;
      for (final term in query.terms) {
        if (!_contains(u.lower, term)) continue;
        hits++;
        score += idf(term) * (entityTerms.contains(term) ? 3 : 1);
      }
      if (hits == 0) continue;
      // Reward passages that cover more of the question.
      score *= 1 + hits / query.terms.length;
      if (u.field != null) score *= 1.3;
      if (u.verified) score *= 1.1;
      if (u.confidence != null && u.confidence! < .6) score *= .7;
      scored.add((u, score));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));

    // A field and the OCR line it came from are the same evidence.
    final seen = <String>{};
    final out = <LegacyEvidence>[];
    for (final (u, score) in scored) {
      final key = '${u.doc.name}|${u.page}|${u.line ?? u.text}';
      if (!seen.add(key)) continue;
      final lineData = u.line == null
          ? null
          : u.doc.lines
              .where((l) => l.page == u.page && l.line == u.line)
              .firstOrNull;
      final box = u.box ?? lineData?.box;
      out.add(LegacyEvidence(
        id: 'L${out.length + 1}',
        documentName: u.doc.name,
        documentType: u.doc.type,
        page: u.page,
        line: u.line,
        zone: box == null ? null : zoneOf(box),
        field: u.field,
        record: u.record,
        text: u.text,
        ocrConfidence: u.confidence ?? lineData?.confidence,
        box: box,
        archivedAt: u.doc.archivedAt,
        score: score,
      ));
      if (out.length >= limit) break;
    }
    return out;
  }

  static bool _contains(String haystack, String term) => term.length <= 3
      ? RegExp('(^|[^a-z0-9])${RegExp.escape(term)}([^a-z0-9]|\$)')
          .hasMatch(haystack)
      : haystack.contains(term);

  static String _label(String name) => name.replaceAll('_', ' ').trim();

  /// Drawing-sheet zone for a normalized box: rows A–F, columns 1–4.
  static String? zoneOf(List<double> box) {
    if (box.length < 4) return null;
    final cx = (box[0] + box[2] / 2).clamp(0.0, .999);
    final cy = (box[1] + box[3] / 2).clamp(0.0, .999);
    return '${'ABCDEF'[(cy * 6).floor()]}${(cx * 4).floor() + 1}';
  }
}

class _Unit {
  _Unit(this.doc, this.text, this.page, this.line,
      {this.field,
      this.record = 0,
      this.verified = false,
      this.confidence,
      this.box})
      : lower = text.toLowerCase();
  final IndexedDocument doc;
  final String text;
  final String lower;
  final int page;
  final int? line;
  final String? field;
  final int record;
  final bool verified;
  final double? confidence;
  final List<double>? box;
}
