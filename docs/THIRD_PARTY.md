# Third-party inventory

Update using the actual resolved dependency lockfile before submission. LegacyLens uses firebase_core 4.15.0, firebase_ai 4.0.0 and firebase_app_check 0.4.8. This inventory is not a certification of all service terms or platform licensing.

Preparation dependencies are now resolved in `preparation/flutter_lab/pubspec.lock`. See [resolved attribution](RESOLVED_DEPENDENCIES.md) and [captured notices](DEPENDENCY_NOTICES.txt). Recheck if dependencies change for the final entry.

The main app's resolved dependencies include shared_preferences 2.5.5 for the old practice draft flow and Flutter's bundled integration_test for native verification. See [starter dependency inventory](STARTER_DEPENDENCIES.md) and [starter license notices](STARTER_DEPENDENCY_NOTICES.txt). The current synthetic directory was authored in this workspace by `scripts/generate-synthetic-directory.py`; it is not a historical record.

| Component | Role | Reference | Release action |
|---|---|---|---|
| Flutter/Dart | Mobile framework/runtime | https://github.com/flutter/flutter | Record resolved version and retain license notices |
| firebase_core | Firebase initialization | https://pub.dev/packages/firebase_core | Record resolved version/license |
| firebase_ai | Firebase AI Logic client | https://pub.dev/packages/firebase_ai | Record resolved version/license |
| firebase_app_check | App attestation | https://pub.dev/packages/firebase_app_check | Record resolved version/license |
| Apple Vision and PDFKit | On-device text recognition and PDF rendering on iOS | Apple platform frameworks | Record minimum supported iOS and platform boundary |
| Firebase/Gemini services | Proprietary hosted inference | https://firebase.google.com/docs/ai-logic/get-started | Document project access, enabled APIs, model and quota |
| Authorized archive sources | Not yet supplied | Pending | Record owner permission, origin, version and permitted demo use |

Do not assume all transitive packages share the top-level package's license. Review the resolved set and any copied sample/assets. The practice source was authored for this workspace; its use of documented APIs does not copy an entire upstream application.
