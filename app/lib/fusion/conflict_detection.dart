import 'fusion_models.dart';
import 'knowledge_fusion.dart';

/// Keeps only conflicts that are grounded on both sides: an archive value that
/// appears in a cited L source and a current value found in a cited W source.
class ConflictDetection {
  const ConflictDetection();

  List<FusionConflict> validate(
      List<FusionConflict> proposed, FusionContext context) {
    final out = <FusionConflict>[];
    final seen = <String>{};
    for (final c in proposed) {
      if (c.attribute.isEmpty ||
          c.historicalValue.isEmpty ||
          c.currentValue.isEmpty) {
        continue;
      }
      if (_norm(c.historicalValue) == _norm(c.currentValue)) continue;

      final lCites =
          c.historicalCites.where(context.legacyIds.contains).toList();
      final wCites = c.currentCites.where(context.webIds.contains).toList();
      if (lCites.isEmpty || wCites.isEmpty) continue;

      final legacyText =
          lCites.map((id) => context.legacyById(id)!.text).join(' ');
      final webText = [
        ...wCites.map((id) => context.webById(id)!.excerpt),
        // Some search engines return no excerpt; the research notes are the
        // only text available for those pages.
        if (wCites.any((id) => context.webById(id)!.excerpt.isEmpty))
          context.webNotes,
      ].join(' ');
      if (!grounded(c.historicalValue, legacyText) ||
          !grounded(c.currentValue, webText)) {
        continue;
      }
      if (!seen.add(_norm(c.attribute))) continue;
      out.add(FusionConflict(
        attribute: c.attribute,
        historicalValue: c.historicalValue,
        historicalCites: lCites,
        currentValue: c.currentValue,
        currentCites: wCites,
        explanation: c.explanation.isEmpty
            ? 'These values come from different sources and time periods. '
                'Confirm which applies to the installed asset.'
            : c.explanation,
      ));
    }
    return out;
  }

  /// True when [value] is supported by [text]: the normalized value appears,
  /// or every number in the value appears in the text.
  static bool grounded(String value, String text) {
    final v = _norm(value);
    final t = _norm(text);
    if (v.isEmpty || t.isEmpty) return false;
    if (t.contains(v)) return true;
    final numbers = RegExp(r'\d+(?:[.,]\d+)?')
        .allMatches(value)
        .map((m) => m.group(0)!.replaceAll(',', ''))
        .toList();
    if (numbers.isEmpty) return false;
    final textNumbers = RegExp(r'\d+(?:[.,]\d+)?')
        .allMatches(text)
        .map((m) => m.group(0)!.replaceAll(',', ''))
        .toSet();
    return numbers.every(textNumbers.contains);
  }

  static String _norm(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9.]'), '');
}
