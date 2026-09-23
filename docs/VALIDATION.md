# Validation record

Prepared September 18, 2026 (Asia/Manila).

## Source inspection

- Read all eight pages of the supplied official mechanics via text extraction.
- Rendered and visually checked page 6 to verify score weights and point breakdown.
- Checked official Flutter installation and Firebase AI Logic documentation.
- Public event homepage returned no extractable current mechanics; no changed event rule was inferred.

## Local checks completed

- Official stable Flutter SDK installed locally: Flutter 3.47.4, Dart 3.13.3. SDK is excluded from the project repository.
- Android project files generated; release manifest includes Internet permission.
- Firebase dependencies downloaded and top-level versions pinned; resolved lockfile retained.
- Updated App Check integration to the installed SDK's non-deprecated provider API.
- `dart format lib test`: passed.
- `flutter analyze`: no issues found.
- `flutter test`: passed; verifies that an unconfigured app explains setup, disables real requests, and does not show a generated result.
- Both shell scripts passed syntax checking.
- Local README links checked; no broken local links found.
- Evaluation CSV parsed successfully: twenty template cases, no recorded results yet.

## Remaining verification and setup

- Initial `flutter doctor -v` snapshot before iPhone setup: Android SDK missing and Xcode/CocoaPods unavailable through the selected tools. The iPhone follow-up below supersedes the Xcode/CocoaPods findings. Android setup remains pending.
- A practice Firebase Spark project and iOS app were registered on September 19; see `LIVE_AI_SETUP.md`. AI Logic activation, App Check registration and a real inference remain unverified.
- Real AI inference, Android build/install, App Check attestation, latency, cost and final user value are not yet verified.
- The assigned theme is now recorded for Team 08. Member identities and exact submission deadline remain pending.
- No public repository, account registration, organizer message or portal submission has been performed.

## iPhone starter — September 18 follow-up

- New main starter in `app/`: Studio, Sessions and Setup tabs; device-local drafts; real Firebase adapter disabled until configured.
- Formatting and analysis passed; four tests passed for connection readiness, the phone workflow and storage update/failure handling.
- Browser preview successfully rendered the designed home screen; a saved draft survived a browser reload.
- Xcode 27.0 license/first-launch tools are now unlocked; workspace commands use its DEVELOPER_DIR.
- CocoaPods 1.17.0 installed. Swift Package Manager explicitly enabled per project after the initial native build exposed missing Firebase modules.
- Exact old iPhone 17 Pro device UUID `8D810668-2580-4CEF-8C27-936AE8E4AC61` deleted; device directory removal checked.
- iPhone 18 Pro actual device type confirmed. Apple arm64 iOS 27.0 runtime installed (build 24A434; 8.05 GB download).
- Native simulator debug build succeeded with Firebase and storage plugins. Installed and launched bundle `dev.appcon.appconStarter` on actual iPhone 18 Pro UUID `7C0EA28F-61C1-4978-9FAA-9BAF33A18D69`. Final source launched successfully through `scripts/run-ios.sh`.
- Captured and visually checked the actual native home screen: `docs/screenshots/iphone18-pro-home.png`. Native touch interactions were not independently exercised; phone-sized automated tests and browser persistence checks cover the draft workflow.
- Real AI inference remains unverified pending AI Logic activation, App Check setup and a successful request.

## September 19 local recheck

- `flutter analyze --no-pub`: no issues found.
- `flutter test --no-pub`: all four tests passed with loopback access; the sandbox alone blocks the test runner's local socket.
- Standard `check-starter.sh` dependency refresh could not finish in the restricted network sandbox. These checks used existing resolved dependencies and did not refresh packages.
- The practice Firebase project is registered, but there is still no verified model response or Android device test.

## September 23 LegacyLens development

- Team 08's theme, judging rubric and LegacyLens product brief were inspected. `LEGACYLENS_PLAN.md` maps each criterion to a specific build or demonstration check.
- New iOS pipeline imports images or scanned PDFs with a 100-page, 100 MB batch limit, uses PDFKit and Apple Vision OCR, and returns line text, location, confidence and source crops. The build passed for iPhone simulator.
- Flutter workspace, review queue, and JSON/CSV export code were added. `flutter analyze --no-pub` found no issues; eight Dart tests passed, including conflict routing, grouped records CSV and export provenance.
- A synthetic personnel directory and ground truth were generated and visually checked. It is not a real historical source or evidence of production accuracy.
- The current iPhone 18 Pro simulator build was installed and launched; its home screen was captured and visually checked in `docs/screenshots/legacylens-home.png`. Two native integration tests passed: the synthetic image traversed Apple Vision OCR with source crops, and the review screen opened with source evidence.
- After the cloud interpretation switch was added, formatting, static analysis, all eight Flutter tests, both native integration tests, and a fresh iOS simulator build passed. The rebuilt app was installed and launched; the refreshed screenshot shows the switch off by default.
- On that one synthetic directory, Apple Vision returned all 16 labeled record cells as exact OCR lines in order. This is a fixture check, not an accuracy estimate for real archives or for Gemini interpretation.
- `flutter pub get` must run with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` on this host. Without it, generated iOS Swift package metadata omits Firebase packages and the native integration test cannot compile.
- A live Gemini smoke attempt initialized Firebase, then the first request failed with App Check's `server-unreachable` category. The app preserved OCR review items. This does not establish whether the cause is network access, API enablement or debug token registration; the Firebase Console state needs checking. No live model response is verified.
- Performance on real historical scans, Android/web import, durable storage, public repository and submission are unverified.

## September 23 Android follow-up

- Added an Android native document channel using the system open/save pickers, `PdfRenderer`, and bundled ML Kit Latin OCR. It returns the same page images, OCR lines, normalized boxes and source crops as the iOS channel to the shared Flutter review/export pipeline.
- Installed a project-local Android SDK with API 36, build tools, platform tools and the Flutter-required NDK. Homebrew JDK 17 runs the build without changing the system Java selection.
- `flutter build apk --debug --no-pub` succeeded and produced `app/build/app/outputs/flutter-apk/app-debug.apk`. Static analysis found no issues and all eight Flutter tests passed after the shared UI change.
- A Pixel 8 Android 16 emulator ran both native integration tests: ML Kit OCR produced source crops and the review screen opened. On the one synthetic directory, an order-independent comparison found 12 of 16 labeled cells as exact OCR lines; all four file numbers were misread. This is a fixture result, not historical archive accuracy.
- The normal Android APK was installed and its Documents screen was visually checked in `docs/screenshots/legacylens-android.png`. The Android system picker imported the synthetic JPG and a one-page PDF made from it. Both produced one source page and 25 OCR review items in the app.
- Android's save picker wrote `synthetic_directory_1978_reviewed.json` to emulator Downloads. The pulled file parsed as `legacylens.v1` with 25 fields, all requiring review and with unresolved values blank.
- No physical Android device was connected. Firebase Android app registration, Android App Check, and a real Android Gemini response remain pending; the verified OCR-only path does not establish connected AI access.

## Optional Vercel tooling

Vercel is not required for the chosen mobile practice architecture. If the team later uses it for a backend or deployment, strongly recommend upgrading the supplied outdated CLI (59.11.7) to the recommended 59.22.0 or newer: `npm i -g vercel@latest` or `pnpm add -g vercel@latest`. No global upgrade or Vercel resource provisioning was performed here.

## September 23 restoration, geometry and AI repair

- Corrected the Gemini client to use the selected Gemini 2.5 model instead of silently rewriting it to Gemini 1.5. Direct REST structured-output keys now use the API's expected JSON names, connection status is no longer called verified before a successful ping, and server messages are surfaced without discarding OCR results.
- A real iPhone-simulator model request reached Firebase App Check and received HTTP 403 `App attestation failed` while exchanging the debug token. This confirms the remaining blocker is Firebase project attestation configuration. No successful live response is claimed.
- A user-supplied candidate token was registered in the Firebase App Check console and injected through the local Xcode debug environment, but the repeated live request received the same HTTP 403. The candidate is therefore not the token currently presented by the SDK. Retrieving the active simulator token requires separate explicit credential-access approval.
- The iOS pipeline now preserves the original scan, produces a grayscale contrast-and-sharpening derivative, runs Apple Vision OCR on both, and chooses the derivative only when line count improves or equal-count mean confidence improves by more than 0.015. The enhanced preview remains separately visible.
- Apple Vision rectangle detection now produces normalized, review-required plan primitives. The app overlays detected geometry and exports unitless SVG and DXF. This is verified as a limited geometric conversion path; object semantics, units and general hand-drawn CAD reconstruction remain review responsibilities.
- PDF and camera batches now accept up to 100 pages and 100 MB. Up to twenty structured checkpoints persist extracted fields, quality indicators and review decisions locally; source images are not duplicated into checkpoints.
- Quality reporting exposes mean OCR confidence, low-confidence lines, source-link rate and unresolved fields. The app explicitly states that these indicators are not a measured accuracy percentage.
- `flutter analyze --no-pub` passed. All ten Flutter tests passed. A fresh iOS simulator build passed. Both native integration tests passed; the synthetic fixture still produced 16/16 exact labeled OCR cells. This remains synthetic evidence and does not establish accuracy on historical archives.

## September 23 final consistency pass

- `dart format` completed, `flutter analyze --no-pub` reported no issues, and all ten Flutter tests passed.
- Fresh debug builds succeeded for both iOS Simulator and Android (`app-debug.apk`).
- After narrowing the active target to iPhone, the current iPhone 18 Pro simulator reran both native integration tests successfully: Apple Vision OCR produced source crops and enhanced imagery for the bundled 1915 evaluation page, detected 15 review-required geometry objects, and the app opened the review queue through the restored sample action.
- Android now implements the Executive Summary PDF save flow instead of exposing an unsupported platform-channel action.
- AI setup status no longer says connected before a successful ping. Direct Gemini keys are session-only and the app removes values persisted by older builds because `shared_preferences` is not encrypted secret storage.
- Removed the source-default App Check debug token, aligned the default and selectable models to Gemini 2.5, and updated the live smoke assertion to require the cloud-result marker rather than accepting deterministic fallback fields.
- Platform copy now identifies Apple Vision on iOS and ML Kit on Android. Automated bulk acceptance and canned historical summaries were removed so unresolved or inferred values are not presented as human-verified facts.
- Shell syntax, Git whitespace, local Markdown links, and common committed-secret patterns were checked. No failures remain in those checks.
- Live Gemini inference, App Check attestation, physical-device testing, historical-source accuracy, public repository publication, and portal submission remain unverified external steps.

## September 23 smart CAD upgrade

- Replaced bounding-box-only iPhone geometry with Vision quadrilateral corner extraction plus filtered top-level contour tracing. Rectangle-like contour duplicates are suppressed and long paths are bounded to keep overlays and exports usable.
- Added OCR dimension-evidence linking, polygon/contour overlays, reviewer scale calibration from one known object width, calibrated SVG view boxes, DXF `$INSUNITS`, separate review layers, and source-label text entities.
- Static analysis passed with no issues. All eleven Flutter tests passed, including calibrated vector export coverage. A fresh iOS simulator build succeeded.
- Both iPhone 18 Pro simulator integration tests passed. The bundled 1915 page produced 16 geometry objects, including at least one traced contour; every returned object had three or more vector vertices, source crops remained available, and the review screen opened successfully.
- These checks establish editable AI-assisted vector reconstruction on one fixture. They do not establish complete line recovery, correct engineering semantics, calibrated accuracy on unseen drawings, or fitness for construction use.

## September 23 iPhone visual cleanup

- The app now launches in a fixed light theme with warm paper surfaces, charcoal text, muted archival green accents, solid borders, and no neon treatment or glass blur.
- Primary navigation, scan/import/sample, AI, and CAD actions use local solid SVG assets. No emoji characters remain in the Flutter source or tests.
- The AI badge says configured rather than active; a configured key still does not claim a verified Gemini response.
- The final iPhone 18 Pro simulator render was inspected for clipping and label overflow. Static analysis passed, all eleven Flutter tests passed, and a fresh iOS simulator build succeeded.
