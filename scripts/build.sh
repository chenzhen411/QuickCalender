#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
configuration="${CONFIGURATION:-release}"
bash scripts/swift-tool.sh build -c "$configuration"
binary_dir="$(bash scripts/swift-tool.sh build -c "$configuration" --show-bin-path)"
mkdir -p dist
stage="$(mktemp -d "${TMPDIR:-/tmp}/QuickCalender-build.XXXXXX")"
app="$stage/QuickCalender.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$binary_dir/QuickCalender" "$app/Contents/MacOS/QuickCalender"
cp Resources/Info.plist "$app/Contents/Info.plist"
CLANG_MODULE_CACHE_PATH="$PWD/.build/local-cache/clang" swift scripts/make-icon.swift "$PWD/dist"
iconutil -c icns dist/AppIcon.iconset -o "$app/Contents/Resources/AppIcon.icns"
xattr -cr "$app"
codesign --force --deep --sign - "$app"
codesign --verify --deep --strict "$app"
ditto -c -k --norsrc --noextattr --keepParent "$app" "$PWD/dist/QuickCalender-macOS.zip"
ditto --norsrc --noextattr "$app" "$PWD/dist/QuickCalender.app"
echo "$app" > dist/.last-build-path
echo "Built and verified: $app"
echo "Installer archive: $PWD/dist/QuickCalender-macOS.zip"
