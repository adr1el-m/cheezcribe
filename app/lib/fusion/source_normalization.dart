import 'fusion_models.dart';

/// Cleans raw provider citations into one [WebSource] per page.
class SourceNormalization {
  const SourceNormalization();

  List<WebSource> normalize(List<RawCitation> raw, {DateTime? retrievedAt}) {
    final at = retrievedAt ?? DateTime.now();
    final byUrl = <String, WebSource>{};
    for (final c in raw) {
      final uri = Uri.tryParse(c.url.trim());
      if (uri == null) continue;
      final key = canonicalUrl(uri);
      final domain = uri.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
      final excerpt = _clean(c.content);
      final existing = byUrl[key];
      if (existing != null) {
        // Keep the longest excerpt seen for the same page.
        if (excerpt.length > existing.excerpt.length) {
          byUrl[key] = WebSource(
            id: '',
            title: existing.title,
            url: existing.url,
            domain: existing.domain,
            retrievedAt: at,
            excerpt: excerpt,
            tier: existing.tier,
          );
        }
        continue;
      }
      final title = _clean(c.title);
      byUrl[key] = WebSource(
        id: '',
        title: title.isEmpty ? domain : title,
        url: uri.removeFragment().toString(),
        domain: domain,
        retrievedAt: at,
        excerpt: excerpt,
        tier: SourceTier.general,
      );
    }
    return byUrl.values.toList();
  }

  static String canonicalUrl(Uri uri) {
    final path = uri.path.endsWith('/') && uri.path.length > 1
        ? uri.path.substring(0, uri.path.length - 1)
        : uri.path;
    return '${uri.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '')}'
        '$path${uri.hasQuery ? '?${uri.query}' : ''}';
  }

  static String _clean(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();
}
