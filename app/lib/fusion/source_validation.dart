import 'fusion_models.dart';

/// Rejects unusable URLs, ranks sources by authority, and assigns W ids.
class SourceValidation {
  const SourceValidation({this.limit = 8});
  final int limit;

  static const _standardsDomains = {
    'iso.org',
    'iec.ch',
    'ieee.org',
    'ansi.org',
    'nfpa.org',
    'astm.org',
    'asme.org',
    'api.org',
    'nema.org',
    'ul.com',
    'ashrae.org',
    'hi.org',
    'pumps.org',
    'din.de',
    'bsigroup.com',
    'cen.eu',
    'awwa.org',
  };
  static const _academicHosts = {
    'arxiv.org',
    'doi.org',
    'sciencedirect.com',
    'springer.com',
    'link.springer.com',
    'wiley.com',
    'onlinelibrary.wiley.com',
    'tandfonline.com',
    'mdpi.com',
    'nature.com',
    'researchgate.net',
    'semanticscholar.org',
    'jstor.org',
  };

  /// Capitalized asset words that are not organization names.
  static const _genericNouns = {
    'pump',
    'pumps',
    'tank',
    'valve',
    'motor',
    'engine',
    'unit',
    'plant',
    'station',
    'boiler',
    'turbine',
    'compressor',
    'generator',
    'line',
    'building',
    'bridge',
    'road',
    'water',
    'works',
    'what',
    'which',
    'when',
  };
  static const _referenceHosts = {
    'wikipedia.org',
    'britannica.com',
    'archive.org',
  };

  List<WebSource> validate(List<WebSource> sources, FusionQuery query) {
    final valid = <WebSource>[];
    for (final s in sources) {
      final uri = Uri.tryParse(s.url);
      if (uri == null ||
          !(uri.scheme == 'https' || uri.scheme == 'http') ||
          !uri.host.contains('.') ||
          RegExp(r'^\d+\.\d+\.\d+\.\d+$').hasMatch(uri.host)) {
        continue;
      }
      valid.add(WebSource(
        id: '',
        title: s.title,
        url: s.url,
        domain: s.domain,
        retrievedAt: s.retrievedAt,
        publishedAt: s.publishedAt,
        excerpt: s.excerpt,
        tier: classify(s.domain, query),
      ));
    }
    final ordered = [
      for (final tier in SourceTier.values)
        ...valid.where((s) => s.tier == tier),
    ].take(limit).toList();
    return [
      for (var i = 0; i < ordered.length; i++) ordered[i].withId('W${i + 1}'),
    ];
  }

  static SourceTier classify(String domain, FusionQuery query) {
    final d = domain.toLowerCase();
    bool endsWithAny(Iterable<String> hosts) =>
        hosts.any((h) => d == h || d.endsWith('.$h'));

    if (RegExp(r'(^|\.)(gov|mil)(\.[a-z]{2})?$').hasMatch(d) ||
        d.endsWith('.gc.ca') ||
        d.endsWith('.europa.eu') ||
        d.endsWith('.gov.uk')) {
      return SourceTier.government;
    }
    if (endsWithAny(_standardsDomains)) return SourceTier.standards;
    if (RegExp(r'(^|\.)(edu|ac\.[a-z]{2}|edu\.[a-z]{2})$').hasMatch(d) ||
        endsWithAny(_academicHosts)) {
      return SourceTier.academic;
    }
    if (endsWithAny(_referenceHosts)) return SourceTier.reference;
    // A domain named after an organization in the question, e.g. a pump
    // maker, is treated as that organization's own documentation.
    final label = d.split('.').reversed.skip(1).firstOrNull ?? '';
    final queryWords = RegExp(r'(?<=\s)[A-Z][a-zA-Z]{3,}')
        .allMatches(query.question)
        .map((m) => m.group(0)!.toLowerCase())
        .where((w) => !_genericNouns.contains(w));
    if (label.length >= 4 &&
        queryWords.any((w) => label.contains(w) || w.contains(label))) {
      return SourceTier.manufacturer;
    }
    return SourceTier.general;
  }
}
