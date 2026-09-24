import 'fusion_models.dart';
import 'knowledge_fusion.dart';
import 'llm_client.dart';

/// Asks the model for an article as structured JSON, one cited statement at a
/// time, so every claim can be checked against the evidence packet.
class ArticleGeneration {
  const ArticleGeneration(this.client, {this.fusion = const KnowledgeFusion()});
  final LlmClient client;
  final KnowledgeFusion fusion;

  static const _system = '''
You write evidence-based technical research articles for Paperazzi, an engineering records system.
You receive HISTORICAL SOURCES [L#] from scanned archive documents and CURRENT SOURCES [W#] from the web.

Rules:
- Use only the provided sources. No outside knowledge, no guessed values.
- Every statement must cite at least one source id in "cites".
- "historical" statements cite only L sources. "current" statements cite only W sources.
- Never describe an L source as current, even if it is the only source.
- If the historical and current sources give different values for the same thing (a rating, voltage, interval, procedure step, part, standard), do not pick one. Add it to "conflicts" with both values exactly as written and their source ids.
- If evidence is missing or thin, say so in "gaps" instead of filling in.
- If there are no CURRENT SOURCES, "current" must be empty and "changes" must not claim anything changed.
- Keep statements short and factual. Use the document's own terms.

Reply with only this JSON:
{
  "title": "article title phrased as the topic, e.g. Current Maintenance Procedure for Pump A",
  "overview": [{"text": "...", "cites": ["L1","W2"]}],
  "historical": [{"text": "...", "cites": ["L1"]}],
  "current": [{"text": "...", "cites": ["W1"]}],
  "changes": [{"text": "...", "cites": ["L2","W1"]}],
  "findings": [{"text": "...", "cites": ["L1"]}],
  "conflicts": [{"attribute": "...", "historical_value": "...", "historical_cites": ["L1"], "current_value": "...", "current_cites": ["W1"], "explanation": "..."}],
  "confidence": "high|medium|low",
  "gaps": ["..."]
}''';

  Future<(DraftArticle, String)> generate(FusionContext context) async {
    final result = await client.complete(
      [
        const LlmMessage.system(_system),
        LlmMessage.user(fusion.render(context)),
      ],
      temperature: .1,
    );
    final json = parseJsonObject(result.text);
    if (json == null) {
      throw const LlmException('The article could not be generated.');
    }
    return (parse(json, context.query), result.model);
  }

  static DraftArticle parse(Map<String, dynamic> json, FusionQuery query) {
    List<FusionStatement> statements(String key) => [
          for (final raw in (json[key] as List? ?? const []))
            if (raw is Map &&
                raw['text'] is String &&
                (raw['text'] as String).trim().isNotEmpty)
              FusionStatement(
                (raw['text'] as String).trim(),
                _ids(raw['cites']),
              )
            else if (raw is String && raw.trim().isNotEmpty)
              FusionStatement(raw.trim(), const []),
        ];

    final title = (json['title'] as String?)?.trim();
    return DraftArticle(
      title: title == null || title.isEmpty ? query.question : title,
      overview: statements('overview'),
      historical: statements('historical'),
      current: statements('current'),
      changes: statements('changes'),
      findings: statements('findings'),
      conflicts: [
        for (final raw in (json['conflicts'] as List? ?? const []))
          if (raw is Map)
            FusionConflict(
              attribute: '${raw['attribute'] ?? ''}'.trim(),
              historicalValue: '${raw['historical_value'] ?? ''}'.trim(),
              historicalCites: _ids(raw['historical_cites']),
              currentValue: '${raw['current_value'] ?? ''}'.trim(),
              currentCites: _ids(raw['current_cites']),
              explanation: '${raw['explanation'] ?? ''}'.trim(),
            ),
      ],
      selfConfidence: switch ('${json['confidence']}'.toLowerCase()) {
        'high' => FusionConfidence.high,
        'medium' => FusionConfidence.medium,
        _ => FusionConfidence.low,
      },
      gaps: [
        for (final g in (json['gaps'] as List? ?? const []))
          if (g is String && g.trim().isNotEmpty) g.trim(),
      ],
    );
  }

  static List<String> _ids(Object? raw) => [
        for (final v in (raw is List ? raw : const []))
          if (v is String)
            v.trim().toUpperCase().replaceAll(RegExp(r'[\[\]\s]'), ''),
      ];
}
