# LegacyLens • AppCon 2026 Team 08

Status: Team 08's **LegacyLens** entry is in development for **Legacy Knowledge Digitization & Asset Redefinition**. Native OCR has been exercised on iPhone and Android simulators. Live AI inference, real archive accuracy, web import and public submission are not yet verified. No winning outcome is guaranteed.

## Product and scorecard

The team supplied the LegacyLens concept on September 23. See [the implementation and judging map](docs/LEGACYLENS_PLAN.md) and [the assigned challenge](docs/TEAM_08_CHALLENGE.md). The current P0 code lives in [`app/`](app/README.md). The bundled 1915 public-works page is an evaluation fixture; confirm its source and demo permission before public presentation.

The app focuses on a reviewable document-to-asset workflow with a dependable iPhone demo. The official mechanics PDF is the source for event requirements; our recommendations are identified separately.

## Start here

1. Read [the competition playbook](docs/PLAYBOOK.md).
2. Complete [team readiness and the build schedule](docs/TEAM_AND_TIMELINE.md).
3. Learn [how AI works in Flutter](docs/FLUTTER_AI.md).
4. Use [Team 08's assigned challenge](docs/TEAM_08_CHALLENGE.md) and [the LegacyLens plan](docs/LEGACYLENS_PLAN.md) to guide implementation.
5. Rehearse [the pitch](docs/PITCH.md) and verify [submission readiness](docs/SUBMISSION.md).

## LegacyLens app

The current main app is [LegacyLens](app/README.md).

- **iPhone 15 (Physical or Simulator)**: See [iPhone 15 Guide](docs/IPHONE_15_GUIDE.md) or launch the simulator directly:
  ```sh
  bash scripts/run-ios-15.sh
  ```
- **iPhone 18 Pro simulator**:
  ```sh
  bash scripts/run-ios.sh
  ```

See [iPhone 15 setup guide](docs/IPHONE_15_GUIDE.md), [iPhone setup and storage record](docs/IOS_STARTER.md), [Android setup](docs/ANDROID_SETUP.md), and [live AI setup](docs/LIVE_AI_SETUP.md). The practice Firebase project is registered for iOS; AI remains unavailable until the model and App Check are configured and a real request succeeds. Android also needs its own Firebase app registration for connected AI.

`preparation/flutter_lab/` contains an Android-focused AI integration exercise, clearly separate from the entry. It sends real requests through Firebase AI Logic when configured. It does not simulate AI responses. An unavailable configuration is displayed honestly.

```sh
export PATH="$PWD/.tooling/flutter/bin:$PATH"
flutter doctor -v
bash scripts/setup-lab.sh
```

See `docs/FLUTTER_AI.md` for Firebase configuration, App Check registration and running on a device. Until the model has returned a response on a device, live AI integration is unverified.

## Entry development

Local Git history starts with a commit explicitly labeled as imported pre-event scaffolding. New LegacyLens work is being developed during the event. The PDF requires commit history showing hackathon progress, but does not explicitly settle whether reusable pre-event scaffolding is allowed. Ask organizers that specific question and disclose what was reused. Do not backdate commits.

## Licensing and attribution

This preparation workspace has an MIT license. Replace the generic copyright holder with the agreed team name for the entry. Record resolved dependency versions and license notices in `docs/THIRD_PARTY.md`. Proprietary AI access is documented in `docs/FLUTTER_AI.md`; people reproducing the app use their own project and quota.

## Verification boundaries

`docs/VALIDATION.md` records what was checked and what still needs a real device, configuration or team input. Public repository publication, portal submission and presentation upload have not been performed.

The earlier starter checks and the current LegacyLens checks are recorded separately. Android physical-device OCR and live Firebase inference are still needed for a connected production claim. The iPhone and Android emulator home screens have been visually checked.
