#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

APP_DIR="$PWD/build/CropAndLock.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
BUNDLE_ID="local.cropandlock.app"
EXECUTABLE_NAME="CropAndLock"

terminate_running_app() {
    local pids
    pids="$(pgrep -x "$EXECUTABLE_NAME" || true)"

    if [[ -z "$pids" ]]; then
        return
    fi

    echo "Stopping running $EXECUTABLE_NAME..."
    pkill -x "$EXECUTABLE_NAME" || true

    for _ in {1..20}; do
        if ! pgrep -x "$EXECUTABLE_NAME" >/dev/null; then
            return
        fi
        sleep 0.1
    done

    pkill -9 -x "$EXECUTABLE_NAME" || true
}

reset_tcc_permissions() {
    if ! command -v tccutil >/dev/null 2>&1; then
        return
    fi

    echo "Resetting TCC permissions for $BUNDLE_ID..."
    tccutil reset ScreenCapture "$BUNDLE_ID" >/dev/null 2>&1 || true
    tccutil reset Accessibility "$BUNDLE_ID" >/dev/null 2>&1 || true
}

swift build -c release

terminate_running_app

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"

cp ".build/release/CropAndLock" "$MACOS_DIR/CropAndLock"
cp "Resources/Info.plist" "$CONTENTS_DIR/Info.plist"

if command -v codesign >/dev/null 2>&1; then
    codesign --force --deep --sign - "$APP_DIR" >/dev/null
fi

reset_tcc_permissions

echo "$APP_DIR"
