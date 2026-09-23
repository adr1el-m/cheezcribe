#!/usr/bin/env bash
set -euo pipefail
printf 'AppCon iPhone simulator setup\nThis Apple setup step needs your Mac administrator password in Terminal.\n'
sudo env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -license accept
sudo env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -runFirstLaunch
printf '\nXcode is ready. You can return to Codex.\n'
