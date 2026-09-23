# LegacyLens judging demo

This script uses only verified facts. Replace bracketed placeholders with real measurements after connected AI and an authorized legacy document are tested. The synthetic directory is clearly labeled during the demo.

## Two to four minute sequence

| Time | Show | Point earned with evidence |
|---|---|---|
| 0:00–0:25 | A scan beside the desired structured directory row | Relevance: aging paper is hard to reuse |
| 0:25–0:50 | Import the synthetic scan; show real OCR lines and original page | Functionality: source is processed, not a canned result |
| 0:50–1:20 | Explain the cloud transfer, enable **Interpret with Gemini**, then import when a live model request has been verified | Technical innovation: image plus OCR becomes document-specific fields |
| 1:20–2:05 | Open one flagged field, compare source crop, OCR and AI, then correct it | Design innovation: focused human review with provenance |
| 2:05–2:35 | Save records CSV, open it, and show rows with status | Value: reusable asset with review state |
| 2:35–3:05 | State actual synthetic field accuracy, review count and time | Impact: measured small-sample result, with limits |
| 3:05–3:30 | Show failure path and architecture in one slide | Maintainability: deterministic validation and explicit service boundary |

If Gemini is not live, demonstrate the OCR and review flow honestly, then state that multimodal interpretation is pending. Do not play a recorded result as a live model call. If a backup recording is used, label when and how it was captured.

## Eight-slide structure

1. **The archive problem.** Team 08 challenge and one specific directory task.
2. **Why current OCR falls short.** Show the same source beside the plain OCR baseline and the structured target. State tool and sample count.
3. **LegacyLens in one sentence.** Source → evidence-linked fields → focused review → reusable export.
4. **Live workflow.** Actual upload, OCR, Gemini if verified, reviewer correction, CSV.
5. **How it works.** Native OCR, multimodal interpretation, deterministic source matching, reviewer decision. Keep original and intermediate data separate.
6. **Results.** Actual exact-cell coverage and review workload on labeled synthetic and permitted real samples. Distinguish each dataset.
7. **Trust and sustainability.** No silent guesses, cost per processed page if measured, retention, setup, what remains unsupported.
8. **Why this approach is distinct.** Narrow comparison with plain OCR and manual transcription; next pilot with an archive owner.

## Current evidence and gaps

- Apple Vision recognized the 16 directory cells exactly on the one synthetic sample in the current iPhone simulator integration run. This says nothing yet about real damaged archives.
- The native source crop and review screen were reached in the simulator integration test.
- A live Gemini response, saved JSON/CSV opened from Files, real-source accuracy, review-time reduction, and cost per page remain to be measured.
- The presentation should use actual UI screenshots from the current build. Do not use the old Matsuri Studio preparation screenshot.
