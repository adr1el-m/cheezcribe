#!/usr/bin/env bash
set -euo pipefail

task_root="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="$task_root/.tooling/flutter/bin:/opt/homebrew/bin:$PATH"
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

if ! xcodebuild -checkFirstLaunchStatus >/dev/null 2>&1; then
  echo 'Complete scripts/finish-xcode-setup.command in Terminal first.' >&2
  exit 1
fi

# Check for physical iPhone first
physical_device=$(flutter devices --device-timeout 2 2>/dev/null | grep -i "iPhone" | grep -v "simulator" | head -n1 | awk -F'•' '{print $2}' | xargs || true)

if [[ -n "$physical_device" ]]; then
  echo "📱 Found physical iPhone: $physical_device"
  echo "Running directly on physical iPhone 15..."
  cd "$task_root/app"
  flutter run -d "$physical_device" "$@"
  exit 0
fi

# Fallback to Simulator
device_id=$(DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl list devices | grep -E "iPhone 15 \(" | head -n1 | grep -oE "[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}" || true)

if [[ -z "$device_id" ]]; then
  echo "Creating iPhone 15 simulator..."
  device_id=$(DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl create "iPhone 15" com.apple.CoreSimulator.SimDeviceType.iPhone-15 com.apple.CoreSimulator.SimRuntime.iOS-27-0)
fi

echo "Booting iPhone 15 simulator ($device_id)..."
if ! xcrun simctl list devices booted | grep -Fq "$device_id"; then
  xcrun simctl boot "$device_id"
fi
xcrun simctl bootstatus "$device_id" -b

# Open the Simulator app
open -a /Applications/Xcode.app/Contents/Developer/Applications/Simulator.app 2>/dev/null || open -a /Applications/Xcode.app/Contents/Applications/DeviceHub.app 2>/dev/null || true

cd "$task_root/app"
echo "Launching LegacyLens on iPhone 15 Simulator..."
flutter run -d "$device_id" "$@"
