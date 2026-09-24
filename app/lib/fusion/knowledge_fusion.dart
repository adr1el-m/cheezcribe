import 'fusion_models.dart';

/// Everything the article generator is allowed to use, with historical and
/// current evidence kept in separate, labeled blocks.
class FusionContext {
  const FusionContext({
    required this.query,
    required this.legacy,
    required this.web,
    required this.webNotes,
    required this.webSearched,
    required this.retrievedAt,
  });
  final FusionQuery query;
  final List<LegacyEvidence> legacy;
  final List<WebSource> web;
  final String webNotes;

  /// False when the question did not need current information or the search
  /// could not run. Distinguishes "not searched" from "nothing found".
  final bool webSearched;
  final DateTime retrievedAt;

  Set<String> get legacyIds => legacy.map((e) => e.id).toSet();
  Set<String> get webIds => web.map((e) => e.id).toSet();

  LegacyEvidence? legacyById(String id) =>
      legacy.where((e) => e.id == id).firstOrNull;
  WebSource? webById(String id) => web.where((e) => e.id == id).firstOrNull;
}

/// Builds the evidence packet that fuses archive and web findings.
class KnowledgeFusion {
  const KnowledgeFusion();

  FusionContext fuse({
    required FusionQuery query,
    required List<LegacyEvidence> legacy,
    required List<WebSource> web,
    required String webNotes,
    required bool webSearched,
    DateTime? retrievedAt,
  }) =>
      FusionContext(
        query: query,
        legacy: legacy,
        web: web,
        webNotes: webNotes,
        webSearched: webSearched,
        retrievedAt: retrievedAt ?? DateTime.now(),
      );

  /// Renders the packet as the model sees it.
  String render(FusionContext c) {
    final b = StringBuffer();
    b.writeln('QUESTION: ${c.query.question}');
    b.writeln();
    b.writeln(
        'HISTORICAL SOURCES — Paperazzi archive. These describe the past. '
        'The archived date is when Paperazzi scanned the document, not when it '
        'was written. Never present them as current.');
    if (c.legacy.isEmpty) {
      b.writeln('(none found)');
    }
    for (final e in c.legacy) {
      b.writeln('[${e.id}] "${e.documentName}" (${e.documentType}), '
          '${e.location}'
          '${e.ocrConfidence == null ? '' : ', OCR ${(e.ocrConfidence! * 100).round()}%'}'
          ', archived ${_day(e.archivedAt)}: "${e.text}"');
    }
    b.writeln();
    b.writeln('CURRENT SOURCES — web pages retrieved ${_day(c.retrievedAt)}.');
    if (!c.webSearched) {
      b.writeln('(not searched)');
    } else if (c.web.isEmpty) {
      b.writeln('(no reliable current source found)');
    }
    for (final w in c.web) {
      b.writeln('[${w.id}] ${w.title} — ${w.domain} (${w.tier.label})'
          '${w.publishedAt == null ? '' : ', published ${_day(w.publishedAt!)}'}'
          '${w.excerpt.isEmpty ? '' : '\n    Excerpt: "${_clip(w.excerpt, 900)}"'}');
    }
    if (c.web.isNotEmpty && c.webNotes.isNotEmpty) {
      b.writeln();
      b.writeln('WEB RESEARCH NOTES — summary of the pages above. A fact from '
          'these notes may be used only when you can cite the [W#] page it '
          'came from.');
      b.writeln(_clip(c.webNotes, 3500));
    }
    return b.toString();
  }

  static String _day(DateTime d) => d.toIso8601String().substring(0, 10);
  static String _clip(String s, int n) =>
      s.length <= n ? s : '${s.substring(0, n)}…';
}
