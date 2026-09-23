#!/usr/bin/env bash
set -euo pipefail
task_root="$(cd "$(dirname "$0")/.." && pwd)"
if [[ ! -f "$task_root/app/ios/Runner/GoogleService-Info.plist" ]]; then
  echo 'iOS Firebase configuration is missing. Register the iOS app in project appcon-2026-ai-practice first.' >&2
  exit 1
fi
exec "$task_root/scripts/run-ios.sh" \
  --dart-define=FIREBASE_ENABLED=true \
  --dart-define=AI_MODEL=gemini-2.5-flash \
  "$@"
