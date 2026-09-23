#!/usr/bin/env bash
set -euo pipefail
task_root="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -x "$task_root/.tooling/flutter/bin/flutter" ]]; then
  export PATH="$task_root/.tooling/flutter/bin:$PATH"
fi
if ! command -v flutter >/dev/null 2>&1; then
  echo 'FAIL: Flutter missing. See https://docs.flutter.dev/install' >&2
  exit 1
fi
flutter --version
flutter doctor -v
flutter devices
if command -v firebase >/dev/null 2>&1; then
  firebase --version
else
  echo 'SETUP NEEDED: Firebase CLI for project configuration.'
fi
if [[ ! -f "$task_root/preparation/flutter_lab/android/app/google-services.json" ]]; then
  echo 'SETUP NEEDED: flutterfire configure and App Check registration.'
fi
echo 'Device listing and doctor results require review; this is not a live AI test.'
