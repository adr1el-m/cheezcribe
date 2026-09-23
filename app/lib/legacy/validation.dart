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
}) {
  final located = lineIndex >= 0 && lineIndex < lines.length;
  final line = located ? lines[lineIndex] : null;
  final cleanValue = value?.trim();
  final hasValue = cleanValue != null && cleanValue.isNotEmpty;
  final ocr = line?.text.trim();
  final candidate = hasValue ? _normalized(cleanValue) : '';
  final evidence = ocr == null ? '' : _normalized(ocr);
  final agrees = candidate.isNotEmpty && evidence.contains(candidate);
  final ocrConfidence = (line?.confidence ?? 0).clamp(0.0, 1.0);
  final score = ((ocrConfidence * 0.55) + (agrees ? 0.45 : 0)).clamp(0.0, 1.0);
  final reason = !hasValue
      ? 'Model could not read this value'
      : !located
          ? 'No source line was linked'
          : !agrees
              ? 'OCR and AI suggestion disagree'
              : ocrConfidence < 0.9
                  ? 'OCR quality needs human review'
                  : 'OCR and AI agree on a clear source line';
  final ready = hasValue && located && agrees && ocrConfidence >= 0.9;
  return LegacyField(
    id: id,
    name: name,
    page: page,
    lineIndex: lineIndex,
    ocrValue: ocr,
    aiValue: hasValue ? cleanValue : null,
    score: score,
    reason: reason,
    status: ready ? FieldStatus.ready : FieldStatus.review,
    recordIndex: recordIndex,
    finalValue: ready ? cleanValue : null,
  );
}
