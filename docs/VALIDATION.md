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
- Assigned theme, team identity and exact submission deadline remain pending.
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

## Optional Vercel tooling

Vercel is not required for the chosen mobile practice architecture. If the team later uses it for a backend or deployment, strongly recommend upgrading the supplied outdated CLI (59.11.7) to the recommended 59.22.0 or newer: `npm i -g vercel@latest` or `pnpm add -g vercel@latest`. No global upgrade or Vercel resource provisioning was performed here.
