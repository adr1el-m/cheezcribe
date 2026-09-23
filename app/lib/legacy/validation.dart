import 'legacy_models.dart';

String _normalized(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

/// Converts a model suggestion into a traceable review item.
/// A high score means fewer visible conflicts, not statistical certainty.
LegacyField validateSuggestion({
  required String id,
  required String name,
  required String? value,
  required int page,
  required int lineIndex,
  required List<OcrLine> lines,
  int recordIndex = 0,
  bool fromAi = true,
}) {
  final cleanValue = value?.trim();
  final hasValue = cleanValue != null && cleanValue.isNotEmpty;
  final candidate = hasValue ? _normalized(cleanValue) : '';

  // Smart line linking: if lineIndex is negative or out of bounds, find matching OCR line
  var effectiveLineIndex =
      lineIndex >= 0 && lineIndex < lines.length ? lineIndex : -1;

  if (effectiveLineIndex < 0 && hasValue && lines.isNotEmpty) {
    // 1. Direct substring search
    for (var i = 0; i < lines.length; i++) {
      final lineNorm = _normalized(lines[i].text);
      if (lineNorm.isNotEmpty &&
          (lineNorm.contains(candidate) ||
              (candidate.length > 5 && candidate.contains(lineNorm)))) {
        effectiveLineIndex = i;
        break;
      }
    }
    // 2. Token-based word match for compound names and values
    if (effectiveLineIndex < 0 && candidate.length > 3) {
      final words = cleanValue
          .toLowerCase()
          .split(RegExp(r'\s+'))
          .where((w) => w.length > 2);
      for (final word in words) {
        final wNorm = _normalized(word);
        for (var i = 0; i < lines.length; i++) {
          if (_normalized(lines[i].text).contains(wNorm)) {
            effectiveLineIndex = i;
            break;
          }
        }
        if (effectiveLineIndex >= 0) break;
      }
    }
  }

  final located = effectiveLineIndex >= 0 && effectiveLineIndex < lines.length;
  final line = located ? lines[effectiveLineIndex] : null;
  final ocr = line?.text.trim();
  final evidence = ocr == null ? '' : _normalized(ocr);
  final agrees = candidate.isNotEmpty &&
      (evidence.contains(candidate) ||
          (candidate.length > 5 && candidate.contains(evidence)));
  final ocrConfidence = (line?.confidence ?? 0).clamp(0.0, 1.0);
  final score = ((ocrConfidence * 0.55) + (agrees ? 0.45 : 0)).clamp(0.0, 1.0);
  final reason = !hasValue
      ? fromAi
          ? 'Gemini could not read this value'
          : 'No structured value could be read'
      : !located
          ? 'No source line was linked'
          : !agrees
              ? fromAi
                  ? 'OCR and Gemini suggestion disagree'
                  : 'Structured value and OCR source disagree'
              : ocrConfidence < 0.9
                  ? 'OCR quality needs human review'
                  : fromAi
                      ? 'OCR and Gemini agree on a clear source line'
                      : 'On-device extraction matches a clear OCR source';
  final ready = hasValue && located && agrees && ocrConfidence >= 0.85;
  return LegacyField(
    id: id,
    name: name,
    page: page,
    lineIndex: effectiveLineIndex,
    ocrValue: ocr,
    aiValue: fromAi && hasValue ? cleanValue : null,
    score: score,
    reason: reason,
    status: ready ? FieldStatus.ready : FieldStatus.review,
    recordIndex: recordIndex,
    suggestedValue: hasValue ? cleanValue : null,
    finalValue: ready ? cleanValue : null,
  );
}
