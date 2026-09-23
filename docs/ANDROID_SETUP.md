# LegacyLens Android setup

The Android app uses the same Flutter document, review, and export workflow as iOS. Its native channel uses Android's document picker and `PdfRenderer` plus bundled, on-device ML Kit Latin OCR. The app accepts images and scanned PDFs of up to 100 pages and 100 MB. OCR can run without Firebase.

## Local SDK and build

This workspace keeps the Android SDK under ignored `.tooling/android-sdk`. The locally installed JDK is Homebrew `openjdk@17`.

```sh
export JAVA_HOME=/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home
export ANDROID_SDK_ROOT="$PWD/.tooling/android-sdk"
export ANDROID_HOME="$ANDROID_SDK_ROOT"
export PATH="$PWD/.tooling/flutter/bin:$ANDROID_SDK_ROOT/platform-tools:$PATH"
cd app
flutter build apk --debug
```

The debug APK appears at `app/build/app/outputs/flutter-apk/app-debug.apk`. A local Pixel 8 AVD named `LegacyLens_Pixel_8` was created with Android API 36. To rerun its checks, start `"$ANDROID_SDK_ROOT/emulator/emulator" -avd LegacyLens_Pixel_8`, run `adb devices`, then `flutter test integration_test/legacy_flow_test.dart -d <device-id> --no-pub`. The integration test runs the labeled synthetic directory through the real Android OCR bridge and opens the review screen. The current emulator run found 12 of 16 labeled cells exactly; all four file numbers were misread. It does not establish real archive accuracy.

The normal Android APK was also installed on the emulator. Its system picker imported the synthetic JPG and a one-page PDF, and its save picker produced a parseable JSON export with unresolved values explicitly marked. The current screen capture is [`legacylens-android.png`](screenshots/legacylens-android.png). A physical Android device has not yet been tested.

## Connected AI

The Android build has no registered Firebase Android app or `google-services.json` yet. OCR-only mode works without it; the **Interpret with Gemini** switch stays off by default. For Android model inference, register package `dev.appcon.appcon_starter` in the team's Firebase project, configure its Android Firebase app and App Check provider, then verify a real model response. Keep the native config and any App Check debug token out of Git. A connected AI claim requires a successful Android device request, not only a successful APK build.

Official API references: [Android document picker](https://developer.android.com/training/data-storage/shared/documents-files), [PDF renderer](https://developer.android.com/reference/android/graphics/pdf/PdfRenderer), [ML Kit text recognition](https://developers.google.com/ml-kit/vision/text-recognition/v2/android).
