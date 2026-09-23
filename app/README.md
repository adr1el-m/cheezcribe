# LegacyLens — Team 08 AppCon entry in progress

LegacyLens turns a legacy page into a reviewable structured asset. The current app targets iOS. It imports an image or scanned PDF of up to five pages, runs Apple Vision OCR on the device, links OCR lines to source crops, optionally asks Gemini for document-specific fields, routes unsupported or conflicting fields to a human review queue, and exports JSON or CSV through the iOS Files picker.

## Run

From the workspace root:

```sh
bash scripts/run-ios.sh
```

Tap **Try synthetic sample** to process the bundled test directory with real OCR. The image and ground truth are in `assets/demo/`; the footer clearly states it is synthetic. This is a development fixture, not evidence of accuracy on historical archives. The **Interpret with Gemini** switch starts off; turn it on before import only for a source you are permitted to send to the hosted model.

To test connected AI, finish `docs/LIVE_AI_SETUP.md` and run:

```sh
bash scripts/run-ai-ios.sh
```

The app works in OCR-only review mode if Firebase AI Logic is unavailable. It never labels OCR-only output as Gemini interpretation. A configured status alone does not prove a live model response.

## Data and review

The original rendered page, OCR text, source crop, AI suggestion, review score, and final reviewer value are separate. The review score is a routing estimate, not a calibrated probability. Unresolved values export as blank with `requires_review` status. Sample counts shown in the UI come from actual processed fields.

Document pages and review decisions are held in memory for this build; export before closing the app. The original input file is never modified. On-device OCR does not upload the page. If connected AI runs, the page image and OCR lines are sent to the configured Gemini service. Use only permitted, non-sensitive documents for the demo.

## Current platform boundary

The native document adapter uses Apple Vision and PDFKit. Android and web need their own OCR adapter before import works there. Full CAD conversion, image restoration, durable document storage, and a public deployment are later work. See `docs/LEGACYLENS_PLAN.md` for priorities and the judging evidence map.

## Checks

```sh
cd app
flutter analyze --no-pub
flutter test --no-pub
flutter build ios --simulator --no-pub
```
