#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

BUILD_ARGS=(-c release)
if [[ -n "${BUILD_ARCHS:-}" ]]; then
    IFS=' ' read -r -a REQUESTED_ARCHS <<< "${BUILD_ARCHS}"
    for ARCH in "${REQUESTED_ARCHS[@]}"; do
        BUILD_ARGS+=(--arch "${ARCH}")
    done
fi

swift build "${BUILD_ARGS[@]}"
BIN_DIR="$(swift build "${BUILD_ARGS[@]}" --show-bin-path)"
APP="$PWD/dist/LingoPane.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/LingoPane" "$APP/Contents/MacOS/LingoPane"
cp Resources/Info.plist "$APP/Contents/Info.plist"
if [[ -n "${APP_VERSION:-}" ]]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${APP_VERSION}" "$APP/Contents/Info.plist"
fi
if [[ -n "${BUILD_NUMBER:-}" ]]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${BUILD_NUMBER}" "$APP/Contents/Info.plist"
fi
if [ -f Resources/AppIcon.icns ]; then
    cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
    /usr/libexec/PlistBuddy -c 'Add :CFBundleIconFile string AppIcon' "$APP/Contents/Info.plist"
fi
codesign --force --options runtime --entitlements Resources/LingoPane.entitlements --sign "${SIGNING_IDENTITY:--}" "$APP"
codesign --verify --deep --strict "$APP"
echo "$APP"
