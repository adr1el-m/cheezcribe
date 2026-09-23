#!/usr/bin/env bash
set -euo pipefail
task_root="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="$task_root/.tooling/flutter/bin:/opt/homebrew/bin:$PATH"
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
if ! xcodebuild -checkFirstLaunchStatus >/dev/null 2>&1; then
  echo 'Complete scripts/finish-xcode-setup.command in Terminal first.' >&2
  exit 1
fi
python_runtime=/Users/adrielmagalona/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3
if [[ ! -x "$python_runtime" ]]; then python_runtime=python3; fi
device_id="$($python_runtime - <<'PY'
import json,subprocess,sys
base=['xcrun','simctl']
def fetch(kind): return json.loads(subprocess.check_output(base+['list',kind,'-j']))[kind]
types=fetch('devicetypes')
model=next((x for x in types if x['identifier']=='com.apple.CoreSimulator.SimDeviceType.iPhone-18-Pro'),None)
if not model:
    sys.exit('This Xcode has no actual iPhone 18 Pro device type. Update Xcode.')
def version(x): return tuple(map(int,x['version'].split('.')))
runtimes=[x for x in fetch('runtimes') if x['isAvailable'] and x['identifier'].startswith('com.apple.CoreSimulator.SimRuntime.iOS-') and version(x)>=(27,0)]
if not runtimes:
    sys.exit('Install iOS 27 runtime: xcodebuild -downloadPlatform iOS -buildVersion 27.0 -architectureVariant arm64')
runtime=max(runtimes,key=version)
devices=fetch('devices').get(runtime['identifier'],[])
existing=next((x for x in devices if x['isAvailable'] and x.get('deviceTypeIdentifier')==model['identifier']),None)
if existing: print(existing['udid'])
else: print(subprocess.check_output(base+['create','iPhone 18 Pro',model['identifier'],runtime['identifier']],text=True).strip())
PY
)"
if ! xcrun simctl list devices booted | grep -Fq "$device_id"; then
  xcrun simctl boot "$device_id"
fi
xcrun simctl bootstatus "$device_id" -b
open -a /Applications/Xcode.app/Contents/Applications/DeviceHub.app
cd "$task_root/app"
flutter run -d "$device_id" "$@"
