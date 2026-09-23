# Team 08 challenge brief

Source: the two theme screenshots supplied by the team on September 23, 2026. This records the assigned challenge; it is not a product idea or authorization to publish, enroll services, or contact organizers.

## Assigned theme

**Legacy Knowledge Digitization & Asset Redefinition**

The challenge asks for a software tool that extracts knowledge from aging paper documents and turns it into usable digital assets with very high accuracy. The examples shown are faded text, unusual document layouts, old directory lists, hand-drawn drawings, and the conversion of drawing elements into meaningful CAD objects. It calls out verification effort as a major cost. The proposed solution should minimize errors while extracting, structuring, and validating the legacy information.

## What the demo must prove

1. Start with a real or clearly labeled synthetic legacy source, with permission to use it.
2. Produce a structured digital asset that serves a named user task. Plain OCR text alone is an intermediate result.
3. Show which part of the source supports each important extracted field or drawing element.
4. Expose uncertain or unreadable parts for human review, correction, and approval.
5. Export or otherwise use the reviewed asset in a format that is meaningful to the chosen task.
6. Measure accuracy and review effort on a small labeled set. State the denominator, error types, and remaining limitations.

These are our proposed acceptance checks, not additional organizer rules. The exact asset type and export format depend on the team's product idea. The screenshot describes both documents and drawings as examples; whether the judges expect both in one prototype needs clarification from the event team.

## Product decision to make with the team

- Primary user and legacy collection: ______
- One painful task today: ______
- Source type for the first demo: ______
- Digital asset and destination format: ______
- Which fields or drawing elements must be exact: ______
- How reviewers correct mistakes: ______
- Sample source files and permission: ______
- Baseline method and success metric: ______
- Official deadline and demo requirements: ______

## Engineering consequences

The current `app/` starter handles typed text and device-local drafts. It does not capture images, read PDFs, locate text on a page, reconstruct CAD geometry, or export a domain asset. Those capabilities must be designed and tested against the selected idea. Do not describe the starter's generic AI answer as verified extraction.

A credible first workflow is source image or page → extraction with field locations → validation against the source → correction screen → reviewed export. Preserve the original source and edits separately. Mark a field as uncertain if evidence is weak; a model's confidence label alone does not establish accuracy.

For drawings, define the exact object class before implementation, such as room outline, component symbol, or dimension. A raster image converted to vector paths is not automatically a meaningful CAD model. Validate geometry and units against a labeled drawing before claiming CAD conversion.

Keep personal or organizational records out of demos unless the owner permits their use. Record whether source images reach a cloud model before uploading them.
