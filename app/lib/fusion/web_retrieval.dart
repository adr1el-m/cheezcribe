import 'fusion_models.dart';
import 'llm_client.dart';

abstract class WebResearcher {
  Future<WebResearch> research(
      FusionQuery query, List<LegacyEvidence> archiveContext);
}

/// Researches current information with the provider's web search. URLs come
/// only from the provider's citation annotations, never from model text.
class LlmWebResearcher implements WebResearcher {
  const LlmWebResearcher(this.client, {this.maxResults = 6});
  final LlmClient client;
  final int maxResults;

  static const noSourceMarker = 'NO_RELIABLE_CURRENT_SOURCE';

  @override
  Future<WebResearch> research(
      FusionQuery query, List<LegacyEvidence> archiveContext) async {
    // A few short archive excerpts help the search find the right asset
    // (manufacturer, model, location). They are disclosed in the UI.
    final hints =
        archiveContext.take(4).map((e) => '- ${_clip(e.text, 160)}').join('\n');
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final result = await client.complete(
      [
        LlmMessage.system(
            'You research current technical information on the web for an '
            'engineering records team. Today is $today.\n'
            'Rules:\n'
            '- Report only what the retrieved pages state. Do not add facts from memory.\n'
            '- Prefer official manufacturer documentation, government sources, '
            'standards organizations, official technical documentation, and '
            'academic sources over forums or marketing pages.\n'
            '- For each fact, name the page it came from.\n'
            '- Mention a publication or update date only if the page states one.\n'
            '- If no retrieved page reliably answers the question, reply with '
            '$noSourceMarker and a one-line reason.'),
        LlmMessage.user('Question: ${query.question}\n'
            '${query.entities.isEmpty ? '' : 'Key identifiers: ${query.entities.join(', ')}\n'}'
            '${hints.isEmpty ? '' : 'Archive excerpts (for search focus only, may be outdated):\n$hints\n'}'
            'Summarize the current information relevant to the question.'),
      ],
      webSearch: true,
      maxResults: maxResults,
      temperature: .1,
    );
    return WebResearch(notes: result.text.trim(), citations: result.citations);
  }

  static String _clip(String s, int n) =>
      s.length <= n ? s : '${s.substring(0, n)}…';
}
