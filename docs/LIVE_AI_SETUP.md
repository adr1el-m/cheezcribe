# Live AI setup for LegacyLens

The no-cost Firebase Spark project `appcon-2026-ai-practice` was created on September 19, 2026. Its Apple app is registered as `dev.appcon.appconStarter` (the current LegacyLens bundle ID). The Flutter app and iPhone 18 Pro simulator run locally. A Firebase Console registration error appeared, but the registered app was subsequently verified in Project settings. The generated native config exists locally and is ignored by Git.

## Next setup steps

A September 23 simulator smoke run reached Firebase initialization but failed on the first model request with App Check's `server-unreachable` category. No model response was received. Check AI Logic API enablement and App Check debug token registration in the Firebase Console, then rerun the smoke test below. The error category alone does not prove which setup item is responsible.

1. In Firebase Console, open **AI services → AI Logic → Get started → Gemini Developer API**. The **Enable APIs** step accepts Google's Gemini API Additional Terms and usage policies and enforces App Check. Leave billing on **Spark** for no-cost use. Do not select Agent Platform Gemini API, which requires billing.
2. Confirm the registered iOS app's `GoogleService-Info.plist` remains in the Runner target. This app currently initializes from that native config. A teammate cloning the repository must configure their own permitted Firebase project or obtain the team's configuration through a private channel.
3. In **Security → App Check**, set up the iOS app with the debug provider for the simulator and register the debug token shown in Xcode/Flutter logs. Keep the token private.
4. From the workspace root, run `bash scripts/run-ai-ios.sh`. It selects the real iPhone 18 Pro simulator and sets `FIREBASE_ENABLED=true` with `gemini-2.5-flash`.
5. In LegacyLens, enable **Cloud Gemini Enrichment**, then tap **Try bundled 1915 sample**. Confirm that the result note explicitly says `Gemini Cloud`, review a field, and export. A configured status or OCR-only result does not prove live inference.

Repeatable check after setup, from `app/` with the installed Xcode selected:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  ../.tooling/flutter/bin/flutter test integration_test/live_ai_smoke_test.dart \
  -d 7C0EA28F-61C1-4978-9FAA-9BAF33A18D69 --no-pub \
  --dart-define=FIREBASE_ENABLED=true \
  --dart-define=AI_MODEL=gemini-2.5-flash
```

The test must report a Gemini interpretation with structured fields. Keep simulator/Xcode logs private because App Check may print a debug token.

The Firebase CLI's Google OAuth request grants broad Firebase and Google Cloud administration across the account. Only authorize that scope if comfortable; manual app configuration is an alternative. Do not share its login code, App Check debug token or account credentials in chat.

Firebase source guidance: https://firebase.google.com/docs/ai-logic/get-started and https://firebase.google.com/docs/flutter/setup
