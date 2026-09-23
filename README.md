# AppCon 2026 • Flutter preparation workspace

Status: preparation, not the final competition entry. Team 08's assigned challenge is **Legacy Knowledge Digitization & Asset Redefinition**. The product idea, team identity and submission cutoff are not yet supplied. A practice Firebase project exists, but live AI inference is not yet verified. No winning outcome is guaranteed.

## Send the idea

Send your idea in any form, even a rough paragraph. If known, include who has the problem, what paper documents or drawings they provide, the digital asset they need, and any sample source material or constraints. Missing details can be worked out during development. We will check it against [Team 08's challenge](docs/TEAM_08_CHALLENGE.md) before locking the entry.

The development path is: settle the one-sentence workflow and acceptance criteria; adapt the Flutter screens and AI task; connect and test a real Firebase response; verify the full phone workflow and failure states; evaluate representative cases; then prepare the public repository, setup guide, demo and pitch. Account access, the official theme and team facts still require information from the team.

We are optimizing for a narrow, useful, genuinely AI-driven product with a dependable mobile demo. The official mechanics PDF is the source for the event requirements; our recommendations are identified separately.

## Start here

1. Read [the competition playbook](docs/PLAYBOOK.md).
2. Complete [team readiness and the build schedule](docs/TEAM_AND_TIMELINE.md).
3. Learn [how AI works in Flutter](docs/FLUTTER_AI.md).
4. Use [Team 08's assigned challenge](docs/TEAM_08_CHALLENGE.md) and [the theme decision worksheet](docs/THEME_DECISION.md) to choose the product.
5. Rehearse [the pitch](docs/PITCH.md) and verify [submission readiness](docs/SUBMISSION.md).

## Practice app

The main runnable starting app is now [Matsuri Studio](app/README.md), with iOS, Android and browser targets, persistent local drafts and a Firebase AI adapter. To open it on iPhone 18 Pro:

```sh
bash scripts/run-ios.sh
```

See [iPhone setup and storage record](docs/IOS_STARTER.md) and [live AI setup](docs/LIVE_AI_SETUP.md). The practice Firebase project is registered; AI remains unavailable until the model and App Check are configured and a real request succeeds.

`preparation/flutter_lab/` contains an Android-focused AI integration exercise, clearly separate from the entry. It sends real requests through Firebase AI Logic when configured. It does not simulate AI responses. An unavailable configuration is displayed honestly.

```sh
export PATH="$PWD/.tooling/flutter/bin:$PATH"
flutter doctor -v
bash scripts/setup-lab.sh
```

See `docs/FLUTTER_AI.md` for Firebase configuration, App Check registration and running on a device. Until the model has returned a response on a device, live AI integration is unverified.

## Entry development

Create the actual entry during the event, with genuine development commits. The PDF requires commit history showing hackathon progress, but does not explicitly settle whether reusable pre-event scaffolding is allowed. Ask organizers that specific question; preserve this preparation history and disclose anything reused. Do not backdate commits.

## Licensing and attribution

This preparation workspace has an MIT license. Replace the generic copyright holder with the agreed team name for the entry. Record resolved dependency versions and license notices in `docs/THIRD_PARTY.md`. Proprietary AI access is documented in `docs/FLUTTER_AI.md`; people reproducing the app use their own project and quota.

## Verification boundaries

`docs/VALIDATION.md` records what was checked and what still needs a real device, configuration or team input. Public repository publication, registration, portal submission and presentation upload have not been performed.

Local validation passed: Flutter 3.47.4 installed, dependencies resolved, analysis clean, setup-state widget test passing. Android SDK/device and Firebase configuration are still needed for a real native AI test.

The new `app/` passes formatting, analysis and four workflow/storage tests. It builds and runs natively on the actual iPhone 18 Pro simulator with iOS 27.0. The rendered home screen was visually checked; see the validation record and `docs/screenshots/iphone18-pro-home.png`.
