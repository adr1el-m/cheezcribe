import 'fusion_models.dart';
import 'knowledge_fusion.dart';

class CitedSections {
  const CitedSections({
    required this.overview,
    required this.historical,
    required this.current,
    required this.changes,
    required this.findings,
    required this.legacySources,
    required this.webSources,
    required this.proposed,
    required this.removed,
  });
  final List<FusionStatement> overview;
  final List<FusionStatement> historical;
  final List<FusionStatement> current;
  final List<FusionStatement> changes;
  final List<FusionStatement> findings;
  final List<LegacyEvidence> legacySources;
  final List<WebSource> webSources;

  /// Statements the model proposed, and how many were removed for lacking a
  /// valid source.
  final int proposed;
  final int removed;
}

/// Maps every statement to real sources and removes the ones it cannot.
class CitationMapping {
  const CitationMapping();

  CitedSections map(DraftArticle draft, FusionContext context,
      List<FusionConflict> conflicts) {
    final legacyIds = context.legacyIds;
    final webIds = context.webIds;
    var proposed = 0;
    var removed = 0;

    List<FusionStatement> keep(List<FusionStatement> input,
        {required bool allowLegacy, required bool allowWeb}) {
      final out = <FusionStatement>[];
      for (final s in input) {
        proposed++;
        final cites = <String>{
          for (final id in s.cites)
            if ((allowLegacy && legacyIds.contains(id)) ||
                (allowWeb && webIds.contains(id)))
              id,
        }.toList();
        if (cites.isEmpty) {
          removed++;
          continue;
        }
        out.add(FusionStatement(s.text, cites));
      }
      return out;
    }

    final hasCurrent = webIds.isNotEmpty;
    final historical =
        keep(draft.historical, allowLegacy: true, allowWeb: false);
    final current = hasCurrent
        ? keep(draft.current, allowLegacy: false, allowWeb: true)
        : <FusionStatement>[];
    // A change needs evidence from both periods.
    final changes = <FusionStatement>[];
    if (hasCurrent) {
      for (final s in keep(draft.changes, allowLegacy: true, allowWeb: true)) {
        if (s.cites.any(legacyIds.contains) && s.cites.any(webIds.contains)) {
          changes.add(s);
        } else {
          removed++;
        }
      }
    } else {
      proposed += draft.changes.length;
      removed += draft.changes.length;
    }
    final overview =
        keep(draft.overview, allowLegacy: true, allowWeb: hasCurrent);
    final findings =
        keep(draft.findings, allowLegacy: true, allowWeb: hasCurrent);

    final cited = <String>{
      for (final list in [overview, historical, current, changes, findings])
        for (final s in list) ...s.cites,
      for (final c in conflicts) ...[...c.historicalCites, ...c.currentCites],
    };
    return CitedSections(
      overview: overview,
      historical: historical,
      current: current,
      changes: changes,
      findings: findings,
      legacySources: context.legacy.where((e) => cited.contains(e.id)).toList(),
      webSources: context.web.where((w) => cited.contains(w.id)).toList(),
      proposed: proposed,
      removed: removed,
    );
  }
}
