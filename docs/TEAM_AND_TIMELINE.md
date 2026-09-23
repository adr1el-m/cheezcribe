# Team and timeline

## Fill from the assigned team

Team: 08. Leader: pending. Assigned challenge: Legacy Knowledge Digitization & Asset Redefinition (September 23 screenshot). Exact cutoff and timezone: pending organizer announcement.

| Owner | Primary responsibility | Concrete handoff |
|---|---|---|
| Member 1 / leader & product | Theme fit, scope, organizer updates, submission | One-page brief and confirmed portal receipt |
| Member 2 / Flutter | Core screens, device build, accessibility | Installable app and working happy/failure paths |
| Member 3 / AI & data | Firebase, prompts, sources, evaluation | Real model request and measured test results |
| Member 4 / design | Interaction, visual system, assets, user observation | Three-screen flow and consented feedback |
| Member 5 / QA & pitch | Reproduction, evidence, deck, demo | Passing checklist and rehearsed pitch |

Roles are our proposed allocation, not the organizer's assignment. Adjust to actual skills; every feature has one owner and a second person who can run it.

## September 18–22 preparation

- Today: verify roster/confirmation, select leader, join assigned Discord, identify Android demo phone and backup phone.
- Next: install Flutter and Android tooling; run a sample on the physical phone. Confirm whether iOS is actually needed before spending time on signing.
- Practice: configure Firebase AI Logic and App Check using non-sensitive prompts; measure latency. Keep training separate from the entry.
- Before opening: confirm organizer questions, check connectivity, agree collaboration/branch conventions, prepare deck structure and evidence capture.

## Event schedule relative to official opening

These are planning targets, not official event hours. Compress them to leave at least two hours before the announced cutoff; do not assume a full 24-hour period.

| Time after draw | Target | Exit condition |
|---|---|---|
| 0–45 min | Theme selection workshop | One user, one problem, one AI task, one measurable result |
| 45–90 min | Brief and technical spike | Real request from phone; one source-backed example if relevant |
| 1.5–4 hours | First vertical workflow | Input → AI → review → action works on device |
| 4–8 hours | Improve output and interaction | Clear, correctable results; empty/loading/retry states |
| 8–12 hours | Evaluate and refine | Twenty recorded cases, failure analysis, prompt/model changes tracked |
| 12–16 hours | Test user value and polish | Real observations or accurately labeled internal pilot |
| 16–18 hours | Freeze features | Working build, setup reproduced by another member |
| 18–20 hours | Pitch and demo rehearsal | Timed story, live path and failure recovery |
| Before cutoff minus 2 hours | Submission-ready package | Public repo, license, build, materials, no secrets |
| Before cutoff | Portal submission | All uploads complete and receipt saved |

If the model is still failing after 90 minutes, reduce the input format and task scope. If the workflow is not complete by hour four, cut features. If no user evidence exists, say "internal pilot" and describe the test honestly.

## Commit convention

Use descriptive commits such as `feat: extract required actions from notice`, `fix: handle unavailable model`, and `docs: record evaluation cases`. Commit working increments during the event. Review secrets before committing. Record reused pre-event work and organizer permission in the entry README.
