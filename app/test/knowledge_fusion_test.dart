import 'dart:convert';
import 'dart:io';

import 'package:appcon_starter/fusion/citation_mapping.dart';
import 'package:appcon_starter/fusion/conflict_detection.dart';
import 'package:appcon_starter/fusion/fusion_models.dart';
import 'package:appcon_starter/fusion/fusion_pipeline.dart';
import 'package:appcon_starter/fusion/knowledge_fusion.dart';
import 'package:appcon_starter/fusion/knowledge_index.dart';
import 'package:appcon_starter/fusion/legacy_retrieval.dart';
import 'package:appcon_starter/fusion/llm_client.dart';
import 'package:appcon_starter/fusion/query_understanding.dart';
import 'package:appcon_starter/fusion/source_normalization.dart';
import 'package:appcon_starter/fusion/source_validation.dart';
import 'package:flutter_test/flutter_test.dart';

IndexedDocument pumpBlueprint() => IndexedDocument(
      name: 'Pump_A_2003.pdf',
      type: 'Engineering Blueprint',
      archivedAt: DateTime(2026, 9, 1),
      lines: const [
        IndexedLine(
            page: 2,
            line: 14,
            text: 'Pump A operates at 220V single phase',
            confidence: .96,
            box: [.1, .2, .5, .03]),
        IndexedLine(
            page: 2,
            line: 15,
            text: 'Lubricate Pump A bearings every 500 hours',
            confidence: .93,
            box: [.1, .24, .5, .03]),
        IndexedLine(
            page: 3, line: 2, text: 'Tank B inlet valve', confidence: .9),
      ],
      fields: const [
        IndexedField(name: 'rated_voltage', value: '220V', page: 2, line: 14),
      ],
    );

class FakeLlm implements LlmClient {
  FakeLlm({this.citations = const [], this.article, this.notes = 'Notes.'});
  final List<RawCitation> citations;
  final Map<String, Object?>? article;
  final String notes;
  final calls = <bool>[];

  @override
  bool get ready => true;
  @override
  String get model => 'fake/model';

  @override
  Future<LlmResult> complete(List<LlmMessage> messages,
      {bool webSearch = false,
      int maxResults = 6,
      double temperature = .2}) async {
    calls.add(webSearch);
    if (webSearch) {
      return LlmResult(text: notes, model: model, citations: citations);
    }
    return LlmResult(text: jsonEncode(article), model: model);
  }
}

class NoKeyLlm implements LlmClient {
  @override
  bool get ready => false;
  @override
  String get model => 'none';
  @override
  Future<LlmResult> complete(List<LlmMessage> messages,
          {bool webSearch = false,
          int maxResults = 6,
          double temperature = .2}) =>
      throw StateError('must not be called');
}

void main() {
  const understanding = QueryUnderstanding();

  group('query understanding', () {
    test('finds the asset and asks for current information', () {
      final q = understanding
          .parse('What is the current maintenance procedure for Pump A?');
      expect(q.entities, contains('Pump A'));
      expect(q.terms, containsAll(['maintenance', 'procedure', 'pump a']));
      expect(q.needsCurrent, isTrue);
    });

    test('historical-only questions skip web research', () {
      final q = understanding
          .parse('What did the original 1915 record say about Tank B?');
      expect(q.needsCurrent, isFalse);
      expect(q.entities, contains('Tank B'));
    });
  });

  test('legacy retrieval ranks the asset with page, line, and zone', () {
    final q = understanding.parse('Pump A voltage');
    final hits = const LegacyRetrieval().search(q, [pumpBlueprint()]);
    expect(hits, isNotEmpty);
    final top = hits.first;
    expect(top.documentName, 'Pump_A_2003.pdf');
    expect(top.page, 2);
    expect(top.line, 14);
    expect(top.zone, isNotNull);
    expect(top.id, 'L1');
    expect(hits.any((h) => h.text.contains('Tank B')), isFalse);
  });

  test('source validation rejects bad URLs, dedupes, and ranks authority', () {
    final q = understanding.parse('Pump A maintenance');
    final raw = [
      const RawCitation(url: 'https://www.pumpforum.com/t/1', title: 'Forum'),
      const RawCitation(url: 'https://pumpforum.com/t/1/', title: 'Dup'),
      const RawCitation(url: 'ftp://files.example.com/a.pdf'),
      const RawCitation(url: 'http://127.0.0.1/x'),
      const RawCitation(url: 'https://www.osha.gov/pumps', title: 'OSHA'),
    ];
    final sources = const SourceValidation()
        .validate(const SourceNormalization().normalize(raw), q);
    expect(sources.map((s) => s.domain), ['osha.gov', 'pumpforum.com']);
    expect(sources.first.tier, SourceTier.government);
    expect(sources.map((s) => s.id), ['W1', 'W2']);
  });

  group('conflicts and citations', () {
    final q = understanding.parse('Current voltage for Pump A');
    final legacy = const LegacyRetrieval().search(q, [pumpBlueprint()]);
    final voltageId = legacy.firstWhere((e) => e.text.contains('220V')).id;
    final context = const KnowledgeFusion().fuse(
      query: q,
      legacy: legacy,
      web: [
        WebSource(
          id: 'W1',
          title: 'Pump A series manual',
          url: 'https://acme.example.com/manual',
          domain: 'acme.example.com',
          retrievedAt: DateTime(2026, 9, 24),
          excerpt: 'The current Pump A model operates at 230V.',
          tier: SourceTier.manufacturer,
        ),
      ],
      webNotes: '',
      webSearched: true,
    );

    test('keeps a grounded conflict and drops an invented one', () {
      final kept = const ConflictDetection().validate([
        FusionConflict(
            attribute: 'Rated voltage',
            historicalValue: '220V',
            historicalCites: [voltageId],
            currentValue: '230V',
            currentCites: const ['W1'],
            explanation: ''),
        FusionConflict(
            attribute: 'Flow rate',
            historicalValue: '40 L/s',
            historicalCites: [voltageId],
            currentValue: '55 L/s',
            currentCites: const ['W1'],
            explanation: ''),
        FusionConflict(
            attribute: 'Phase',
            historicalValue: 'single phase',
            historicalCites: [voltageId],
            currentValue: 'three phase',
            currentCites: const ['W9'],
            explanation: ''),
      ], context);
      expect(kept.map((c) => c.attribute), ['Rated voltage']);
      expect(kept.single.explanation, contains('different sources'));
    });

    test('removes statements without a valid source of the right kind', () {
      final draft = DraftArticle(
        title: 't',
        overview: const [
          FusionStatement('Supported.', ['W1']),
          FusionStatement('Unsupported.', []),
        ],
        historical: [
          FusionStatement('Old voltage.', [voltageId]),
          const FusionStatement('Web fact in history.', ['W1']),
        ],
        current: [
          const FusionStatement('New voltage.', ['W1']),
          FusionStatement('Archive fact as current.', [voltageId]),
          const FusionStatement('Made-up source.', ['W7']),
        ],
        changes: [
          FusionStatement('Voltage rose.', [voltageId, 'W1']),
          const FusionStatement('Only one side.', ['W1']),
        ],
        findings: const [],
        conflicts: const [],
        selfConfidence: FusionConfidence.high,
        gaps: const [],
      );
      final s = const CitationMapping().map(draft, context, const []);
      expect(s.overview.map((x) => x.text), ['Supported.']);
      expect(s.historical.map((x) => x.text), ['Old voltage.']);
      expect(s.current.map((x) => x.text), ['New voltage.']);
      expect(s.changes.map((x) => x.text), ['Voltage rose.']);
      expect(s.removed, 5);
      expect(s.webSources.single.id, 'W1');
    });
  });

  group('pipeline', () {
    Future<KnowledgeStore> store() async =>
        MemoryKnowledgeStore()..save(pumpBlueprint());

    test('fuses archive and web into a cited article with conflicts', () async {
      final llm = FakeLlm(
        citations: const [
          RawCitation(
              url: 'https://acme.example.com/manual',
              title: 'Pump A series manual',
              content: 'The current Pump A model operates at 230V. Lubricate '
                  'bearings every 1,000 hours.'),
        ],
        article: {
          'title': 'Current Maintenance Procedure for Pump A',
          'overview': [
            {
              'text': 'Lubrication interval changed.',
              'cites': ['L2', 'W1']
            }
          ],
          'historical': [
            {
              'text': 'Bearings every 500 hours.',
              'cites': ['L2']
            }
          ],
          'current': [
            {
              'text': 'Bearings every 1,000 hours.',
              'cites': ['W1']
            },
            {
              'text': 'Invented fact.',
              'cites': ['W4']
            },
          ],
          'changes': [
            {
              'text': 'Interval doubled.',
              'cites': ['L2', 'W1']
            }
          ],
          'findings': [],
          'conflicts': [
            {
              'attribute': 'Rated voltage',
              'historical_value': '220V',
              'historical_cites': ['L1'],
              'current_value': '230V',
              'current_cites': ['W1'],
            }
          ],
          'confidence': 'high',
          'gaps': [],
        },
      );
      final stages = <FusionStage>[];
      final outcome =
          await KnowledgeFusionPipeline(store: await store(), llm: llm).run(
              'What is the current maintenance procedure for Pump A?',
              onStage: stages.add);
      final a = outcome.article!;
      expect(stages, FusionStage.values);
      expect(llm.calls, [true, false]);
      expect(a.title, 'Current Maintenance Procedure for Pump A');
      expect(a.current.map((s) => s.text), ['Bearings every 1,000 hours.']);
      expect(a.hasConflicts, isTrue);
      expect(a.conflicts.single.historicalValue, '220V');
      // Only the URL the search provider returned is ever shown.
      expect(
          a.webSources.map((w) => w.url), ['https://acme.example.com/manual']);
      expect(a.legacySources.map((e) => e.documentName).toSet(),
          {'Pump_A_2003.pdf'});
      expect(a.notices.any((n) => n.contains('removed')), isTrue);
    });

    test('says so when no reliable current source is found', () async {
      final llm = FakeLlm(
        notes: 'NO_RELIABLE_CURRENT_SOURCE: nothing specific found',
        citations: const [
          RawCitation(url: 'https://random.example.com', title: 'Random')
        ],
        article: {
          'title': 'Pump A maintenance',
          'overview': [
            {
              'text': 'Archive lists a 500 hour interval.',
              'cites': ['L2']
            }
          ],
          'historical': [
            {
              'text': 'Bearings every 500 hours.',
              'cites': ['L2']
            }
          ],
          'current': [
            {
              'text': 'Probably still 500 hours.',
              'cites': ['L2']
            }
          ],
          'changes': [
            {
              'text': 'Nothing changed.',
              'cites': ['L2']
            }
          ],
          'confidence': 'medium',
        },
      );
      final outcome =
          await KnowledgeFusionPipeline(store: await store(), llm: llm)
              .run('What is the current maintenance procedure for Pump A?');
      final a = outcome.article!;
      expect(a.webSources, isEmpty);
      expect(a.current, isEmpty);
      expect(a.changes, isEmpty);
      expect(a.notices.first, contains('No reliable current source'));
      expect(a.confidence, isNot(FusionConfidence.high));
    });

    test('without a key returns archive matches and never calls a model',
        () async {
      final outcome =
          await KnowledgeFusionPipeline(store: await store(), llm: NoKeyLlm())
              .run('Pump A voltage');
      expect(outcome.article, isNull);
      expect(outcome.archiveMatches, isNotEmpty);
      expect(outcome.message, contains('Connect OpenRouter'));
    });
  });

  test('file knowledge store round-trips without images and can be cleared',
      () async {
    final dir = await Directory.systemTemp.createTemp('pz_index');
    addTearDown(() => dir.delete(recursive: true));
    final s = FileKnowledgeStore(directory: () async => dir);
    await s.save(pumpBlueprint());
    final docs = await s.list();
    expect(docs.single.name, 'Pump_A_2003.pdf');
    expect(docs.single.lines.first.box, isNotNull);
    expect(docs.single.fields.single.value, '220V');
    await s.clear();
    expect(await s.list(), isEmpty);
  });

  final key = Platform.environment['OPENROUTER_API_KEY'] ?? '';
  test('live OpenRouter Knowledge Fusion', () async {
    final outcome = await KnowledgeFusionPipeline(
      store: MemoryKnowledgeStore()..save(pumpBlueprint()),
      llm: OpenRouterClient(apiKey: key),
    ).run('What is the current recommended bearing lubrication interval for '
        'centrifugal pumps like Pump A?');
    final a = outcome.article;
    // ignore: avoid_print
    print(const JsonEncoder.withIndent('  ').convert({
      'message': outcome.message,
      'title': a?.title,
      'confidence': a?.confidence.name,
      'current': a?.current.map((s) => '${s.text} ${s.cites}').toList(),
      'historical': a?.historical.map((s) => '${s.text} ${s.cites}').toList(),
      'conflicts': a?.conflicts.map((c) => c.attribute).toList(),
      'web':
          a?.webSources.map((w) => '${w.id} ${w.tier.name} ${w.url}').toList(),
      'notices': a?.notices,
    }));
    expect(a, isNotNull);
    for (final w in a!.webSources) {
      expect(Uri.parse(w.url).isAbsolute, isTrue);
    }
  },
      skip: key.isEmpty ? 'Set OPENROUTER_API_KEY to run' : false,
      timeout: const Timeout(Duration(minutes: 3)));
}
