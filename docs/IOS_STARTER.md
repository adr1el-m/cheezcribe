# iPhone starter setup and verification

## Starting app

The runnable application is `app/`, displayed as **Matsuri Studio**. The earlier `preparation/flutter_lab/` remains a separate Android learning exercise.

The starter has three tabs: Studio, Sessions and Setup. It supports local drafts, reopening/editing, deletion, genuine cloud requests when configured, readable errors and copying generated responses. A failed or disconnected model never produces a fake response.

## Xcode configuration

This machine has Xcode 27.0. The system command-line-tool selection originally pointed to `/Library/Developer/CommandLineTools`. Workspace scripts use `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` so a global change is not needed.

Apple license and first-launch setup required administrator authentication. The prepared Terminal script is `scripts/finish-xcode-setup.command`. CocoaPods 1.17.0 was installed for native plugin fallback. The project explicitly enables Swift Package Manager in its pubspec; the first build exposed missing Firebase modules when SwiftPM was disabled, so it was enabled per project.

## Simulator device and storage

The requested old device was identified by both name and actual type:

- Name: iPhone 17 Pro
- UUID: `8D810668-2580-4CEF-8C27-936AE8E4AC61`
- Type: `com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro`
- Reported data size before removal: 2,480,660,480 bytes (approximately 2.3 GiB / 2.4 GB)
- Deleted with Apple's `simctl delete`; its device directory is gone.

The actual iPhone 18 Pro type is `com.apple.CoreSimulator.SimDeviceType.iPhone-18-Pro`. Its minimum runtime is iOS 27.0. The old installed iOS 26.5 runtime cannot run that device type. The arm64 iOS 27.0 runtime (build 24A434) is installed; download size reported by Apple: 8.05 GB. Installing it adds storage; deleting a device does not remove a shared OS runtime.

No iPhone 17 Pro Max, iPhone 17, iPad device or shared iOS 26.5 runtime was selected for removal.

## Start again

```sh
bash scripts/run-ios.sh
```

This script finds or creates the actual iPhone 18 Pro using an available iOS 27+ runtime, boots it and runs the app. Xcode 27's simulator app is named DeviceHub.

## AI configuration

No Firebase project has been supplied. The app therefore opens without Firebase initialization and keeps generation unavailable. Configure a real project using the steps in `app/README.md`, register App Check and run with both `FIREBASE_ENABLED=true` and your enabled model ID. This is separate from proving the native UI launches.

## Verification

- Flutter formatting and static analysis passed for `app/`.
- Four tests passed: connection readiness updating an open session; phone-sized save/reopen/delete without model calls; updating and restoring a draft; failed storage writes preserving prior drafts and allowing a later retry.
- A browser preview rendered the designed UI and preserved a saved draft after reloading.
- Native debug build, installation and launch succeeded on iPhone 18 Pro (`7C0EA28F-61C1-4978-9FAA-9BAF33A18D69`) with iOS 27.0. The actual simulator screenshot was visually checked and saved as `docs/screenshots/iphone18-pro-home.png`.
- Real AI inference remains unverified without Firebase configuration.
- Run Flutter checks before the native build rather than concurrently: parallel Flutter commands can rewrite the generated SwiftPM graph during a build.

Official tooling reference: https://docs.flutter.dev/platform-integration/ios/setup

SwiftPM reference: https://docs.flutter.dev/packages-and-plugins/swift-package-manager/for-app-developers
