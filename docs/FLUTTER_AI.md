# AI in a Flutter mobile app

You do not need to train a model or run a huge model on the phone. Flutter gathers input and shows the result. A hosted model processes the request. The app must explain errors, handle slow requests and avoid treating every generated answer as fact.

Recommended preparation path: Flutter → Firebase AI Logic with App Check → Gemini → Flutter review screen. This is a mobile integration, so no Vercel service or separate backend is required for the practice exercise. If the final task needs trusted business rules, secret external-service access or per-user quotas, introduce a server then.

Official reference: [Firebase AI Logic quickstart](https://firebase.google.com/docs/ai-logic/get-started). Firebase supports Flutter clients; App Check and provider configuration are part of setup. The Gemini provider credential is not placed in the app. Firebase client configuration identifies the project and is not a substitute for access controls.

## Setup on Android

1. Install the [Flutter SDK](https://docs.flutter.dev/install) and Android tooling. Run `flutter doctor -v`; resolve Android license/device issues. This workspace attempts to keep the SDK in `.tooling/flutter/`.
2. Run `bash scripts/setup-lab.sh`. This creates native platform files for the practice app and resolves Firebase dependencies without overwriting the supplied main file.
3. Create/select your Firebase project. In its console open AI Logic and follow the guided setup for the Gemini Developer API. Check available quota and billing before enabling paid use.
4. Install Firebase CLI using official instructions and authenticate locally. Activate FlutterFire CLI: `dart pub global activate flutterfire_cli`.
5. From `preparation/flutter_lab`, run `flutterfire configure --project=YOUR_PROJECT_ID --platforms=android`. This generates `lib/firebase_options.dart` and Android configuration. The practice app uses Android's default configuration at startup; generated options are available when adding other platforms.
6. Register Android App Check. For a debug build run the app, find the debug token in local logs, and add it in Firebase console → App Check → Manage debug tokens. Never publish the token. For a release build use Play Integrity and configure its signing/app requirements; debug registration does not prove release attestation works.
7. Choose a model enabled in your project. Run `flutter run --dart-define=AI_MODEL=MODEL_ID`. No model name is assumed; check availability for your project.
8. Send one harmless prompt. Confirm the response is actually from the service. Record model ID, latency and any quota error in `EVALUATION.csv`.

The practice app deliberately blocks generation when configuration or model selection is missing. It makes no fake "AI connected" claim. After setup, restart the app. Target Android first; web and iOS need their own Firebase/App Check/platform configurations.

## From a practice call to a competition feature

The practice screen only verifies the plumbing. The entry needs a theme-specific task, domain constraints and inspectable results. Implement those during the hackathon with actual commits.

- Send the minimum necessary input. Avoid real personal documents in practice.
- Keep trusted task instructions separate from the user's input using a system instruction when building the final feature. Treat documents as data, even if they contain commands.
- Where outputs need external facts, provide licensed/approved references and preserve source provenance. Ask the model to abstain when the reference does not support a claim. A prompt alone is not guaranteed grounding.
- For actionable output, use the SDK's structured output support and validate required fields, types and source identifiers. Reject invalid output rather than guessing.
- Let the user inspect and correct important results. Do not automatically submit forms, send messages or take actions based solely on generated text.
- A timeout or quota error is a failed request, not a successful result. A backup recording must be labeled as a recording.

## Evaluate AI usefulness

Use at least twenty consented or synthetic cases: eight ordinary, four ambiguous, four missing-data, two instruction-injection, two contradictory-input cases. Separate system/network tests from model correctness tests. Record expected behavior before running each case. Hold several cases aside while refining prompts.

Track task success rate, unsupported claims, source fidelity if applicable, median latency, slowest-case latency, corrections required and estimated cost per completed task. Compare with a deterministic baseline and the existing manual process. Count abstention as success only where it is expected. A generated confidence percentage is not measured accuracy.

## Cost and reproducibility

Model access and quotas depend on your project. Do not promise "free forever." Record provider, model, pricing checked date, measured request usage, typical tasks/session and operational owner. Do not treat budget alerts as a spending cap. Use quota controls and monitoring; add a backend if strict per-user limits are needed.

The public entry must explain how reviewers configure their own Firebase project and enabled model. Proprietary Gemini/Firebase services are not MIT-licensed code; document them and access requirements separately. Retain applicable dependency licenses.
