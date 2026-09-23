#!/usr/bin/env bash
set -euo pipefail
task_root="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -x "$task_root/.tooling/flutter/bin/flutter" ]]; then
  export PATH="$task_root/.tooling/flutter/bin:$PATH"
fi
if ! command -v flutter >/dev/null 2>&1; then
  echo 'Flutter is missing. Install the official SDK: https://docs.flutter.dev/install' >&2
  exit 1
fi
cd "$task_root/preparation/flutter_lab"
# Generate only missing platform files; do not overwrite authored lab source.
flutter create --no-pub --platforms=android --project-name=appcon_ai_lab .
flutter pub get
dart format lib test
flutter analyze
flutter test
echo 'Practice code verified. Configure Firebase and test real AI on Android next.'
