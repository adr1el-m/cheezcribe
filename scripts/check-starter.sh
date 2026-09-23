#!/usr/bin/env bash
set -euo pipefail
task_root="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="$task_root/.tooling/flutter/bin:/opt/homebrew/bin:$PATH"
cd "$task_root/app"
flutter pub get
dart format lib test
flutter analyze
flutter test
