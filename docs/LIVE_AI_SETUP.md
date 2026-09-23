# Live AI setup for Matsuri Studio

The no-cost Firebase Spark project `appcon-2026-ai-practice` was created on September 19, 2026. Its Apple app is registered as `dev.appcon.appconStarter` (Matsuri Studio iOS). The Flutter app and iPhone 18 Pro simulator already run locally. A Firebase Console registration error appeared, but the registered app was subsequently verified in Project settings.

## Next setup steps

1. In Firebase Console, open **AI services → AI Logic → Get started → Gemini Developer API**. The **Enable APIs** step accepts Google's Gemini API Additional Terms and usage policies and enforces App Check. Leave billing on **Spark** for no-cost use. Do not select Agent Platform Gemini API, which requires billing.
2. Configure the iOS Firebase app in `app/` using the official FlutterFire CLI, or download `GoogleService-Info.plist` from Project settings → General → Matsuri Studio iOS and include it in the Runner target. This app currently initializes from that native config.
3. In **Security → App Check**, set up the iOS app with the debug provider for the simulator and register the debug token shown in Xcode/Flutter logs. Keep the token private.
4. From the workspace root, run `bash scripts/run-ai-ios.sh`. It selects the real iPhone 18 Pro simulator and sets `FIREBASE_ENABLED=true` with `gemini-3.8-flash`.
5. On the app's Studio screen, choose **Simplify text**, enter a harmless sentence, tap **Generate**, and confirm that actual model output appears. A saved draft or a configured status alone does not prove live inference.

The Firebase CLI's Google OAuth request grants broad Firebase and Google Cloud administration across the account. Only authorize that scope if comfortable; manual app configuration is an alternative. Do not share its login code, App Check debug token or account credentials in chat.

Firebase source guidance: https://firebase.google.com/docs/ai-logic/get-started and https://firebase.google.com/docs/flutter/setup
