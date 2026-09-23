# Matsuri Studio — AppCon Flutter starter

A designed, mobile-first starting foundation. This is not the finished assigned-theme entry.

## Working features

- Studio home and task selection.
- Create, save, reopen, edit and delete device-local sessions.
- Real Firebase AI Logic adapter with separate task instructions, App Check, timeout and honest error handling.
- Copy actual generated responses after review.
- Setup screen that reports real configuration state.

AI is disabled by default because no Firebase project exists yet. Drafts work without a cloud account. There are no simulated model responses or invented sessions.

## Run on iPhone 18 Pro simulator

From the workspace root:

```sh
bash scripts/run-ios.sh
```

The script selects the actual iPhone 18 Pro device type, requires iOS 27+, boots it and runs Flutter. It never substitutes a renamed older phone. Xcode 27 calls the simulator application DeviceHub.

## Enable AI

Create a Firebase project, enable AI Logic with an accessible Gemini model, authenticate Firebase CLI locally and activate FlutterFire CLI. From this app directory:

```sh
flutterfire configure --project=YOUR_PROJECT_ID --platforms=ios,android
flutter run -d YOUR_SIMULATOR_ID \
  --dart-define=FIREBASE_ENABLED=true \
  --dart-define=AI_MODEL=YOUR_ENABLED_MODEL
```

FlutterFire registers `dev.appcon.appconStarter` on iOS and generates the native Firebase configurations. This app initializes from native default configuration; verify GoogleService-Info.plist is included in the Runner target. If using generated Dart options instead, import its generated file in `FirebaseAiService` and pass its platform options to initialization.

Register your simulator App Check debug token in Firebase console. Enable `-FIRDebugEnabled` in the Xcode Run scheme if needed to see it in logs. Never commit the debug token. Production builds use App Attest with DeviceCheck fallback on Apple platforms and Play Integrity on Android; each must be configured and independently tested.

A loaded configuration is not proof of inference: send a non-sensitive prompt and confirm a real response. Model availability and quotas depend on the chosen project.

## Checks

```sh
bash ../scripts/check-starter.sh
```

The tests cover the phone-sized draft workflow, session updates/reload and failed writes. They use test-only dependencies; the running app uses actual device preferences and the Firebase adapter.

## Storage and boundaries

Practice sessions use shared_preferences on this device. This is not suitable for important records and is not encrypted application storage. Use harmless practice inputs; deleting the app removes its local data. No upload happens until the user requests generation with connected AI. Provider timeout may stop local waiting without cancelling server computation.

Keep original input and generated output distinct; edits clear a prior response. The starting task prompts are preparation capabilities, not a claim of validated impact or final domain accuracy. Add theme-specific structures, references, validation and meaningful evaluation during the hackathon.

MIT for authored code. Dependency licenses and proprietary Firebase/Gemini access remain separate. See the workspace docs for competition rules and licensing.
