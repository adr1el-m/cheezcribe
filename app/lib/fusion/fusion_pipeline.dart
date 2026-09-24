import 'package:flutter/foundation.dart';

import 'article_generation.dart';
import 'citation_mapping.dart';
import 'confidence_assessment.dart';
import 'conflict_detection.dart';
import 'fusion_models.dart';
import 'knowledge_fusion.dart';
import 'knowledge_index.dart';
import 'legacy_retrieval.dart';
import 'llm_client.dart';
import 'query_understanding.dart';
import 'source_normalization.dart';
import 'source_validation.dart';
import 'web_retrieval.dart';

/// Question → archive + web research → fused, cited article.
///
/// Each stage is its own service so the UI (or a test) only sees
/// [run] and its stage callback.
class KnowledgeFusionPipeline {
  KnowledgeFusionPipeline({
    required this.store,
    required this.llm,
    WebResearcher? web,
    this.understanding = const QueryUnderstanding(),
    this.retrieval = const LegacyRetrieval(),
    this.normalization = const SourceNormalization(),
    this.validation = const SourceValidation(),
    this.fusion = const KnowledgeFusion(),
    this.conflicts = const ConflictDetection(),
    this.citations = const CitationMapping(),
    this.confidence = const ConfidenceAssessment(),
  }) : web = web ?? LlmWebResearcher(llm);

  final KnowledgeStore store;
  final LlmClient llm;
  final WebResearcher web;
  final QueryUnderstanding understanding;
  final LegacyRetrieval retrieval;
  final SourceNormalization normalization;
  final SourceValidation validation;
  final KnowledgeFusion fusion;
  final ConflictDetection conflicts;
  final CitationMapping citations;
  final ConfidenceAssessment confidence;

  Future<FusionOutcome> run(String question,
      {ValueChanged<FusionStage>? onStage}) async {
    onStage?.call(FusionStage.understanding);
    final query = understanding.parse(question);

    onStage?.call(FusionStage.archive);
    final legacy = retrieval.search(query, await store.list());

    if (!llm.ready) {
      return FusionOutcome(
        query: query,
        archiveMatches: legacy,
        message: legacy.isEmpty
            ? 'No archive record matched. Connect OpenRouter to research current sources.'
            : 'Archive matches are shown below. Connect OpenRouter to research current sources and generate a Knowledge Fusion article.',
      );
    }

    final notices = <String>[];
    var webSources = <WebSource>[];
    var notes = '';
    var searched = false;
    final retrievedAt = DateTime.now();
    if (query.needsCurrent) {
      onStage?.call(FusionStage.web);
      try {
        final research = await web.research(query, legacy);
        searched = true;
        final noSource =
            research.notes.contains(LlmWebResearcher.noSourceMarker);
        webSources = validation.validate(
            normalization.normalize(research.citations,
                retrievedAt: retrievedAt),
            query);
        notes = noSource ? '' : research.notes;
        if (noSource) webSources = [];
      } catch (error) {
        debugPrint('Knowledge Fusion web research failed: $error');
        notices.add('Current sources could not be searched right now, so '
            'this answer uses the Paperazzi archive only.');
      }
    }

    onStage?.call(FusionStage.comparing);
    final context = fusion.fuse(
      query: query,
      legacy: legacy,
      web: webSources,
      webNotes: notes,
      webSearched: searched,
      retrievedAt: retrievedAt,
    );

    onStage?.call(FusionStage.generating);
    final DraftArticle draft;
    final String model;
    try {
      (draft, model) =
          await ArticleGeneration(llm, fusion: fusion).generate(context);
    } catch (error) {
      debugPrint('Knowledge Fusion synthesis failed: $error');
      return FusionOutcome(
        query: query,
        archiveMatches: legacy,
        message: error is LlmException && error.message.startsWith('OpenRouter')
            ? '${error.message}. Archive matches are shown below.'
            : 'The article could not be generated. Archive matches are shown below.',
      );
    }

    final verifiedConflicts = conflicts.validate(draft.conflicts, context);
    final sections = citations.map(draft, context, verifiedConflicts);
    final (rating, reasons) = confidence.assess(
      query: query,
      sections: sections,
      modelRating: draft.selfConfidence,
      conflicts: verifiedConflicts.length,
    );

    if (!query.needsCurrent) {
      notices
          .add('This question was answered from the Paperazzi archive only.');
    } else if (searched && webSources.isEmpty) {
      notices.add('No reliable current source was found. Archive records may '
          'be out of date; treat them as historical.');
    }
    if (legacy.isEmpty) {
      notices.add('No Paperazzi archive record matched this question.');
    }
    if (sections.removed > 0) {
      notices.add('${sections.removed} statement'
          '${sections.removed == 1 ? ' was' : 's were'} removed because no '
          'source supported ${sections.removed == 1 ? 'it' : 'them'}.');
    }
    if (sections.webSources.any((w) => w.publishedAt == null)) {
      notices.add('Publication dates were not provided with the current '
          'sources; retrieval dates are shown instead.');
    }
    notices.addAll(draft.gaps.map((g) => 'Evidence gap: $g'));

    return FusionOutcome(
      query: query,
      archiveMatches: legacy,
      article: FusionArticle(
        question: query.question,
        title: draft.title,
        overview: sections.overview,
        historical: sections.historical,
        current: sections.current,
        changes: sections.changes,
        findings: sections.findings,
        conflicts: verifiedConflicts,
        confidence: rating,
        confidenceReasons: reasons,
        legacySources: sections.legacySources,
        webSources: sections.webSources,
        notices: notices,
        generatedAt: DateTime.now(),
        model: model,
      ),
    );
  }
}
