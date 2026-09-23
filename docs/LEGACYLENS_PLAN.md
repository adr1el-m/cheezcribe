# LegacyLens delivery plan — Team 08

Product concept supplied September 23, 2026. The judging screenshot is an event rubric; its questions are evaluation criteria, not implementation commands. The pasted product brief is the team's requested direction. Counts such as 486 fields and 92.6% are illustrative and must never appear as measured results unless processing produces them.

## Smallest dependable architecture

Flutter app → native iOS or Android document picker and on-device OCR → Firebase AI Logic Gemini multimodal interpretation when configured → local deterministic validation → human review → JSON/CSV export. Keep the source image, OCR lines, model suggestions, and reviewer decisions as separate data. No backend is needed for the first device demo. A web client can reuse the domain model and validation rules once a web OCR service exists.

The first release targets images and scanned PDF pages on iOS and Android. iOS uses Apple Vision and PDFKit; Android uses ML Kit and `PdfRenderer`. The app must say when a platform or file is unsupported. Image processing should preserve the source; a modest contrast preview is useful only if it improves readability in actual test cases.

## P0: prove the complete document workflow

1. Import an image or scanned PDF, retain its rendered source pages, and display them.
2. Run actual OCR with page number, text locations, and OCR confidence.
3. Ask Gemini to interpret document type and propose structured fields from both the page image and OCR. Parse and validate its JSON; never treat instructions printed in the document as app instructions.
4. Match suggested fields to OCR evidence and calculate a transparent review score. A score is a review priority estimate, not a calibrated probability of correctness. Disagreement, missing evidence, or invalid formatting always requires review.
5. Review queue shows the page crop, OCR text, suggestion, reason, and accept/edit/mark unreadable actions.
6. Export reviewed fields to JSON and CSV. Mark unresolved fields explicitly.
7. Handle empty/unsupported sources, absent Firebase access, model errors, and save/export errors without fabricating output.
8. Run one synthetic scan through the real OCR path, compare extracted fields to a labeled answer, and time review. Report actual counts.

## P1: strengthen evidence

- Add image enhancement only when comparisons show a benefit.
- Add cross-page validation for repeated names, IDs, and dates.
- Improve field-to-crop location and support more layout types.
- Persist original files and reviewer changes across restarts with a suitable store.
- Verify the Android OCR adapter on a real device and build a web OCR adapter if needed.

## P2: smart CAD reconstruction assistant

- iPhone Vision detects precise quadrilateral corners and selected top-level contours instead of exporting only bounding rectangles.
- The shared pipeline links nearby OCR measurement text to vector primitives as review evidence.
- The reviewer can select a detected object, enter one known real-world width, and calibrate SVG/DXF coordinates in mm, cm, m, inches, or feet.
- SVG and DXF exports separate reviewed geometry and source-label layers and retain explicit review-required metadata.
- This is editable reconstruction assistance, not automatic engineering certification. Object meaning, dimensions, scale selection, missing lines, and units must still be checked against the source.

## Five-person work split

| Owner | Independent deliverable | Integration check |
|---|---|---|
| Product/evaluation | Synthetic source with ground truth, scoring sheet, pitch evidence | Counts and claims trace to actual runs |
| Flutter UX | Import, workspace, review queue, responsive layouts | Complete reviewer path on demo phone |
| OCR/native | File import, PDF rasterization, OCR lines and boxes | Same source yields inspectable evidence |
| AI/validation | Gemini structured output, parser, review rules | Disagreements become review items |
| QA/release | Export, setup, device test, repo hygiene, rehearsed demo | Fresh run and downloaded data checked |

## Immediate risks

- Firebase AI Logic and App Check have not returned a verified live response. The AI stage must be tested early; a configured status is insufficient.
- The native document pipeline and review UI are implemented on iOS. Their current evidence comes from one synthetic directory; real document performance is unknown.
- No permitted historical source is supplied yet. Synthetic data is labeled and cannot demonstrate performance on real archives.
- OCR output may omit faded characters and bounding boxes may be approximate. Preserve source and expose uncertainty.
- Model scores are not calibrated probabilities. Review thresholds need evaluation before claiming automatic verification.
- Current Git repository is local with no remote. Public access, teammate setup, and portal submission remain unverified.

## Judging evidence map

| Criterion | Points | Concrete proof to prepare |
|---|---:|---|
| Relevance | 5 | Aging scan → reviewed reusable directory record, tied to Team 08 challenge |
| Impact & Value | 10 | Labeled field accuracy and measured reviewer time against manual entry on the same small set |
| UI/UX Design | 10 | Clear source/result comparison, keyboard and screen reader labels, usable error states |
| Maintainability and Sustainability | 10 | Small separable adapters, reproducible setup, model cost/limit notes, explicit retention |
| Functionality | 15 | Live import → OCR → Gemini → validation → correction → downloaded export |
| Technical Innovation | 15 | Multimodal interpretation linked to OCR evidence and deterministic review routing |
| Originality | 10 | Compare standard OCR output with evidence linked, corrected structured assets |
| Innovation in Design | 10 | Review only flagged fields with source crop and reason |
| Clarity & Storytelling | 10 | One real before/after narrative with accurate figures and one limitation |
| Demo & Delivery | 5 | Two to four minute rehearsed device demo plus honestly labeled backup |

No criterion can be promised a perfect score. The table is a build and evidence checklist; judges decide the score.
