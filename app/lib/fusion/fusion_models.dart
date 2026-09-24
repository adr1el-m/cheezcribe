/// Data types shared by the Knowledge Fusion pipeline. Nothing here depends on
/// Flutter widgets, so the pipeline can run in tests or another UI.
library;

enum FusionConfidence { high, medium, low }

/// Pipeline progress, reported to whatever UI is listening.
enum FusionStage {
  understanding('Understanding question'),
  archive('Researching Paperazzi Archive'),
  web('Searching Current Sources'),
  comparing('Comparing Information'),
  generating('Generating Knowledge Fusion');

  const FusionStage(this.label);
  final String label;
}

/// A parsed user question.
class FusionQuery {
  const FusionQuery({
    required this.question,
    required this.terms,
    required this.entities,
    required this.needsCurrent,
  });
  final String question;

  /// Lowercased search terms, stop words removed.
  final List<String> terms;

  /// Asset-like identifiers and quoted phrases, e.g. "Pump A", "P-201".
  final List<String> entities;

  /// Whether the question asks about the present, not only the archive.
  final bool needsCurrent;
}

/// A passage from a Paperazzi document, with its provenance.
class LegacyEvidence {
  const LegacyEvidence({
    required this.id,
    required this.documentName,
    required this.documentType,
    required this.page,
    required this.text,
    required this.archivedAt,
    this.line,
    this.zone,
    this.field,
    this.record = 0,
    this.ocrConfidence,
    this.box,
    this.score = 0,
  });

  /// Citation id, e.g. L1. Assigned after ranking.
  final String id;
  final String documentName;
  final String documentType;
  final int page;

  /// 1-based OCR line on the page, when known.
  final int? line;

  /// Drawing-sheet zone (rows A–F, columns 1–4), when the box is known.
  final String? zone;

  /// Extracted field name when the passage is a structured value.
  final String? field;
  final int record;
  final String text;
  final double? ocrConfidence;
  final List<double>? box;

  /// When Paperazzi archived the document. This is not the date the document
  /// was written; the archive does not know that.
  final DateTime archivedAt;
  final double score;

  LegacyEvidence withId(String value) => LegacyEvidence(
        id: value,
        documentName: documentName,
        documentType: documentType,
        page: page,
        text: text,
        archivedAt: archivedAt,
        line: line,
        zone: zone,
        field: field,
        record: record,
        ocrConfidence: ocrConfidence,
        box: box,
        score: score,
      );

  String get location => [
        'page $page',
        if (zone != null) 'zone $zone',
        if (line != null) 'line $line',
        if (field != null) 'field "$field"',
      ].join(', ');
}

/// Rough authority ranking used to order and weigh web sources.
enum SourceTier {
  government('Government'),
  standards('Standards body'),
  academic('Academic / research'),
  manufacturer('Manufacturer / official'),
  reference('Reference'),
  general('General web');

  const SourceTier(this.label);
  final String label;

  bool get authoritative =>
      this == government ||
      this == standards ||
      this == academic ||
      this == manufacturer;
}

/// A web page returned by the search provider. Only URLs the provider
/// actually returned ever become a [WebSource].
class WebSource {
  const WebSource({
    required this.id,
    required this.title,
    required this.url,
    required this.domain,
    required this.retrievedAt,
    required this.excerpt,
    required this.tier,
    this.publishedAt,
  });
  final String id;
  final String title;
  final String url;
  final String domain;
  final DateTime retrievedAt;

  /// Only set when the provider reports it. Never inferred.
  final DateTime? publishedAt;
  final String excerpt;
  final SourceTier tier;

  WebSource withId(String value) => WebSource(
        id: value,
        title: title,
        url: url,
        domain: domain,
        retrievedAt: retrievedAt,
        excerpt: excerpt,
        tier: tier,
        publishedAt: publishedAt,
      );
}

/// Result of the web research step before normalization.
class WebResearch {
  const WebResearch({required this.notes, required this.citations});
  final String notes;
  final List<RawCitation> citations;

  static const empty = WebResearch(notes: '', citations: []);
}

class RawCitation {
  const RawCitation({required this.url, this.title = '', this.content = ''});
  final String url;
  final String title;
  final String content;
}

/// One sentence of the article and the sources that support it.
class FusionStatement {
  const FusionStatement(this.text, this.cites);
  final String text;
  final List<String> cites;
}

/// A value that differs between the archive and a current source.
class FusionConflict {
  const FusionConflict({
    required this.attribute,
    required this.historicalValue,
    required this.historicalCites,
    required this.currentValue,
    required this.currentCites,
    required this.explanation,
  });
  final String attribute;
  final String historicalValue;
  final List<String> historicalCites;
  final String currentValue;
  final List<String> currentCites;
  final String explanation;
}

/// Model output before citation checks.
class DraftArticle {
  const DraftArticle({
    required this.title,
    required this.overview,
    required this.historical,
    required this.current,
    required this.changes,
    required this.findings,
    required this.conflicts,
    required this.selfConfidence,
    required this.gaps,
  });
  final String title;
  final List<FusionStatement> overview;
  final List<FusionStatement> historical;
  final List<FusionStatement> current;
  final List<FusionStatement> changes;
  final List<FusionStatement> findings;
  final List<FusionConflict> conflicts;
  final FusionConfidence selfConfidence;

  /// Evidence gaps the model reported.
  final List<String> gaps;
}

/// The finished, citation-checked article.
class FusionArticle {
  const FusionArticle({
    required this.question,
    required this.title,
    required this.overview,
    required this.historical,
    required this.current,
    required this.changes,
    required this.findings,
    required this.conflicts,
    required this.confidence,
    required this.confidenceReasons,
    required this.legacySources,
    required this.webSources,
    required this.notices,
    required this.generatedAt,
    required this.model,
  });
  final String question;
  final String title;
  final List<FusionStatement> overview;
  final List<FusionStatement> historical;
  final List<FusionStatement> current;
  final List<FusionStatement> changes;
  final List<FusionStatement> findings;
  final List<FusionConflict> conflicts;
  final FusionConfidence confidence;
  final List<String> confidenceReasons;

  /// Sources cited by the article.
  final List<LegacyEvidence> legacySources;
  final List<WebSource> webSources;

  /// Plain-language limits the reader should know about.
  final List<String> notices;
  final DateTime generatedAt;
  final String model;

  bool get hasConflicts => conflicts.isNotEmpty;
}

/// What the pipeline returns. [article] is null when synthesis could not run;
/// archive matches are still returned so the user sees what was found.
class FusionOutcome {
  const FusionOutcome({
    required this.query,
    required this.archiveMatches,
    this.article,
    this.message,
  });
  final FusionQuery query;
  final List<LegacyEvidence> archiveMatches;
  final FusionArticle? article;
  final String? message;
}
