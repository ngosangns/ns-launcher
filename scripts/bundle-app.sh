#!/usr/bin/env bash
#
# Assembles NSLauncher.app from an already-built release binary.
#
# This exists because `task bundle` and .github/workflows/release.yml used to
# carry two hand-maintained copies of these steps, and they drifted. One
# script, called by both, is the only way that stays fixed.
#
# Usage: scripts/bundle-app.sh [version]
#   version — optional CFBundleShortVersionString/CFBundleVersion to stamp.
#             Omitted (local builds) keeps whatever Resources/Info.plist says.
#
# Prints the assembled bundle's path on stdout; run it from the repo root.

set -euo pipefail

APP_NAME="${APP_NAME:-NSLauncher}"
# Must match CFBundleExecutable in Resources/Info.plist.
BIN_NAME="${BIN_NAME:-NSLauncher}"
VERSION="${1:-}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

BIN_PATH="$(swift build -c release --show-bin-path)"
APP_BUNDLE="$BIN_PATH/$APP_NAME.app"
# SwiftPM emits this only when Package.swift lists resources. The launcher
# currently ships none; copy it when a future resources entry brings it back.
RESOURCE_BUNDLE="ns-launcher_NSLauncherApp.bundle"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"

if [ -n "$VERSION" ]; then
  plutil -replace CFBundleShortVersionString -string "$VERSION" Resources/Info.plist -o "$APP_BUNDLE/Contents/Info.plist"
  plutil -replace CFBundleVersion -string "$VERSION" "$APP_BUNDLE/Contents/Info.plist"
else
  cp Resources/Info.plist "$APP_BUNDLE/Contents/Info.plist"
fi

cp "$BIN_PATH/NSLauncherApp" "$APP_BUNDLE/Contents/MacOS/$BIN_NAME"
"$BIN_PATH/IconGen" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

# SwiftPM's own resource bundle (the `resources:` entries in Package.swift) —
# `Bundle.module` looks for it under Contents/Resources at runtime. Must be
# copied before codesign; copying afterwards invalidates the signature.
if [ -d "$BIN_PATH/$RESOURCE_BUNDLE" ]; then
  cp -R "$BIN_PATH/$RESOURCE_BUNDLE" "$APP_BUNDLE/Contents/Resources/"
fi

codesign --force --sign - "$APP_BUNDLE"
codesign --verify --strict "$APP_BUNDLE"

echo "$APP_BUNDLE"
