# LegacyLens — Team 08 AppCon entry in progress

LegacyLens turns legacy pages into reviewable structured assets. It imports an image or scanned PDF in sequential batches of up to 100 pages, links OCR lines to source crops, optionally asks Gemini 2.5 for document-specific fields, routes unsupported or conflicting fields to a human review queue, and exports JSON or CSV through the platform save picker. iOS uses Apple Vision with measured dual-pass image enhancement; Android uses bundled ML Kit Latin text recognition.

## Run

From the workspace root:

```sh
bash scripts/run-ios.sh
```

Tap **Try bundled 1915 sample** to process the bundled public-works page with real OCR. It is a single evaluation fixture, not evidence of accuracy on historical archives; confirm its source and demo permission before public presentation. The **Cloud Gemini Enrichment** switch starts off; turn it on before import only for a source you are permitted to send to the hosted model.

To test connected AI, finish `docs/LIVE_AI_SETUP.md` and run:

```sh
bash scripts/run-ai-ios.sh
```

The app works in OCR-only review mode if Firebase AI Logic is unavailable. It never labels OCR-only output as Gemini interpretation. A configured status alone does not prove a live model response.

## Data and review

The original rendered page, OCR text, source crop, AI suggestion, review score, and final reviewer value are separate. The review score is a routing estimate, not a calibrated probability. Unresolved values export as blank with `requires_review` status. Sample counts shown in the UI come from actual processed fields.

The app automatically stores up to twenty device-local structured checkpoints containing extracted fields, quality indicators, and review decisions. Source images are deliberately excluded from checkpoints and remain in the active session, so retain the permitted source and export before closing. The original input file is never modified. On-device OCR does not upload the page. If connected AI runs, the page image and OCR lines are sent to the configured Gemini service. Use only permitted, non-sensitive documents for the demo.

For drawing pages, the iPhone pipeline detects quadrilaterals and selected contours, overlays their true vertices, associates nearby OCR dimension labels, and exports editable SVG/DXF. Use **Calibrate CAD scale** with one reviewer-confirmed reference width before relying on DXF coordinates. All inferred geometry, text associations, units, and scale remain review-required.

## Current platform boundary

On iOS, a grayscale contrast and sharpening derivative is compared against original-scan OCR and selected only when line count or mean confidence improves. The original scan remains visible. Apple Vision also detects rectangular plan geometry; the app overlays it and exports review-required, unitless SVG and DXF primitives. This is a controlled rectangle workflow, not general semantic CAD reconstruction. Web still needs an OCR adapter, and real historical-source accuracy remains unmeasured.

## Checks

```sh
cd app
flutter analyze --no-pub
flutter test --no-pub
flutter build ios --simulator --no-pub
```

For Android SDK setup and a debug build, see [`docs/ANDROID_SETUP.md`](../docs/ANDROID_SETUP.md). Android Firebase configuration is separate from the on-device OCR build.
