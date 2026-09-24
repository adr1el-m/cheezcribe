import 'fusion_models.dart';
import 'citation_mapping.dart';

/// Rates an answer from the evidence behind it, then caps it at the model's
/// own rating. The reasons are shown to the reader.
class ConfidenceAssessment {
  const ConfidenceAssessment();

  (FusionConfidence, List<String>) assess({
    required FusionQuery query,
    required CitedSections sections,
    required FusionConfidence modelRating,
    required int conflicts,
  }) {
    final reasons = <String>[];
    final legacy = sections.legacySources;
    final web = sections.webSources;

    final ocr = legacy.map((e) => e.ocrConfidence).whereType<double>().toList();
    final meanOcr =
        ocr.isEmpty ? null : ocr.reduce((a, b) => a + b) / ocr.length;
    final authoritative = web.where((w) => w.tier.authoritative).length;
    final removedShare =
        sections.proposed == 0 ? 0.0 : sections.removed / sections.proposed;

    reasons.add(legacy.isEmpty
        ? 'No archive record supports the answer'
        : '${legacy.length} archive source${legacy.length == 1 ? '' : 's'}'
            '${meanOcr == null ? '' : ', OCR ${(meanOcr * 100).round()}% mean'}');
    if (query.needsCurrent) {
      reasons.add(web.isEmpty
          ? 'No reliable current source'
          : '${web.length} current source${web.length == 1 ? '' : 's'}, '
              '$authoritative authoritative');
    }
    if (sections.removed > 0) {
      reasons.add(
          '${sections.removed} unsupported statement${sections.removed == 1 ? '' : 's'} removed');
    }
    if (conflicts > 0) {
      reasons.add(
          '$conflicts conflict${conflicts == 1 ? '' : 's'} between archive and current sources');
    }

    FusionConfidence rating;
    final thinArchive = legacy.isEmpty;
    final thinCurrent = query.needsCurrent && web.isEmpty;
    if ((thinArchive && thinCurrent) ||
        (thinArchive && !query.needsCurrent) ||
        removedShare > .4) {
      rating = FusionConfidence.low;
    } else if (!thinArchive &&
        !thinCurrent &&
        legacy.length >= 2 &&
        (meanOcr == null || meanOcr >= .85) &&
        (!query.needsCurrent || authoritative >= 1) &&
        removedShare <= .15) {
      rating = FusionConfidence.high;
    } else {
      rating = FusionConfidence.medium;
    }
    if (modelRating.index > rating.index) {
      rating = modelRating;
      reasons.add('Synthesis reported limited evidence');
    }
    return (rating, reasons);
  }
}
