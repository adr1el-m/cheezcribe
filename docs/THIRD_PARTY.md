# Third-party inventory

Update using the actual resolved dependency lockfile before submission. Preparation uses firebase_core 4.15.0, firebase_ai 4.0.0 and firebase_app_check 0.4.8. Domain assets remain pending the theme draw; this inventory is not a certification of all service terms or platform licensing.

Preparation dependencies are now resolved in `preparation/flutter_lab/pubspec.lock`. See [resolved attribution](RESOLVED_DEPENDENCIES.md) and [captured notices](DEPENDENCY_NOTICES.txt). Recheck if dependencies change for the final entry.

The main starter's resolved dependencies include shared_preferences 2.5.5 for device-local practice drafts. See [starter dependency inventory](STARTER_DEPENDENCIES.md) and [starter license notices](STARTER_DEPENDENCY_NOTICES.txt). Its app icon is authored geometric artwork, with the source renderer in `scripts/generate-starter-icon.py`.

| Component | Role | Reference | Release action |
|---|---|---|---|
| Flutter/Dart | Mobile framework/runtime | https://github.com/flutter/flutter | Record resolved version and retain license notices |
| firebase_core | Firebase initialization | https://pub.dev/packages/firebase_core | Record resolved version/license |
| firebase_ai | Firebase AI Logic client | https://pub.dev/packages/firebase_ai | Record resolved version/license |
| firebase_app_check | App attestation | https://pub.dev/packages/firebase_app_check | Record resolved version/license |
| Firebase/Gemini services | Proprietary hosted inference | https://firebase.google.com/docs/ai-logic/get-started | Document project access, enabled APIs, model and quota |
| Final domain references/assets | Pending theme | Pending | Record source, permission/license, version and attribution |

Do not assume all transitive packages share the top-level package's license. Review the resolved set and any copied sample/assets. The practice source was authored for this workspace; its use of documented APIs does not copy an entire upstream application.
