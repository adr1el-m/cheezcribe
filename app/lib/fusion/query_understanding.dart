import 'fusion_models.dart';

/// Turns a question into search terms, asset identifiers, and whether current
/// information is needed. Deterministic, so it works offline and is testable.
class QueryUnderstanding {
  const QueryUnderstanding();

  static const _stopWords = {
    'a',
    'an',
    'the',
    'and',
    'or',
    'of',
    'for',
    'to',
    'in',
    'on',
    'at',
    'by',
    'is',
    'are',
    'was',
    'were',
    'be',
    'been',
    'it',
    'its',
    'this',
    'that',
    'what',
    'which',
    'who',
    'whom',
    'how',
    'when',
    'where',
    'why',
    'does',
    'do',
    'did',
    'can',
    'could',
    'should',
    'would',
    'about',
    'with',
    'from',
    'me',
    'my',
    'our',
    'we',
    'you',
    'your',
    'tell',
    'show',
    'give',
    'any',
    'there',
    'their',
    'they',
    'current',
    'currently',
    'latest',
    'now',
    'today',
    'still',
    'please',
    'paperazzi',
    'document',
    'documents',
  };

  static const _currentWords = [
    'current',
    'currently',
    'latest',
    'now',
    'today',
    'modern',
    'present',
    'recommended',
    'recommendation',
    'standard',
    'standards',
    'updated',
    'still',
    'nowadays',
    'replacement',
    'regulation',
    'compliance',
    'code',
  ];

  static final _historicalOnly = RegExp(
      r'\b(originally|original|historical|historically|in (1[6-9]|20)\d\d|'
      r'at the time|back then|according to the (archive|record|document))\b',
      caseSensitive: false);

  FusionQuery parse(String question) {
    final q = question.trim();
    final entities = <String>{};

    for (final m in RegExp(r'"([^"]{2,60})"|“([^”]{2,60})”').allMatches(q)) {
      entities.add((m.group(1) ?? m.group(2))!.trim());
    }
    // Tag-style identifiers: P-201, V-17, TK-3A, 12-B.
    for (final m in RegExp(r'\b[A-Z]{1,4}-?\d{1,5}[A-Z]?\b').allMatches(q)) {
      entities.add(m.group(0)!);
    }
    // Named assets: "Pump A", "Unit 3", "Tank No. 2".
    for (final m
        in RegExp(r'\b([A-Z][a-z]{2,})\s+(?:No\.?\s*)?([A-Z]|\d{1,4}[A-Z]?)\b')
            .allMatches(q)) {
      entities.add(m.group(0)!);
    }
    // Consecutive capitalized words mid-sentence: "Fairbanks Morse".
    for (final m in RegExp(r'(?<=\s)([A-Z][a-zA-Z]+(?:[\s-][A-Z][a-zA-Z]+)+)')
        .allMatches(q)) {
      entities.add(m.group(0)!);
    }

    final terms = <String>[];
    for (final raw in q.toLowerCase().split(RegExp(r'[^a-z0-9\-]+'))) {
      final t = raw.replaceAll(RegExp(r'^-+|-+$'), '');
      if (t.length < 2 || _stopWords.contains(t)) continue;
      if (t.length == 2 && !RegExp(r'\d').hasMatch(t)) continue;
      if (!terms.contains(t)) terms.add(t);
    }
    for (final e in entities) {
      final t = e.toLowerCase();
      if (!terms.contains(t)) terms.add(t);
    }

    final lower = q.toLowerCase();
    final asksCurrent =
        _currentWords.any((w) => RegExp('\\b$w\\b').hasMatch(lower));
    final needsCurrent = asksCurrent || !_historicalOnly.hasMatch(q);

    return FusionQuery(
      question: q,
      terms: terms,
      entities: entities.toList(),
      needsCurrent: needsCurrent,
    );
  }
}
