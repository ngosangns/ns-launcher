#!/usr/bin/env bash
#
# Assembles NSLauncher.app from an already-built release binary.
#
# This exists because `task bundle` and .github/workflows/release.yml used to
# carry two hand-maintained copies of these steps, and they drifted: the
# workflow never copied SwiftPM's resource bundle, so every released .app
# shipped without Resources/Story and the Story tab came up empty while local
# `task bundle` builds looked fine. One script, called by both, is the only
# way that stays fixed.
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

# Subdirectories that must be present inside SwiftPM's resource bundle for the
# app to be usable. Keep in sync with `resources:` in Package.swift — a missing
# one means a whole tab silently renders empty, which is exactly the failure
# this script was written to stop shipping.
REQUIRED_RESOURCE_DIRS=(Story Abyss)

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

BIN_PATH="$(swift build -c release --show-bin-path)"
APP_BUNDLE="$BIN_PATH/$APP_NAME.app"
RESOURCE_BUNDLE="ns-launcher_NSLauncherApp.bundle"

if [ ! -d "$BIN_PATH/$RESOURCE_BUNDLE" ]; then
  echo "error: $RESOURCE_BUNDLE missing from $BIN_PATH — bundled content would ship empty." >&2
  echo "       Run 'swift build -c release' first." >&2
  exit 1
fi

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
cp -R "$BIN_PATH/$RESOURCE_BUNDLE" "$APP_BUNDLE/Contents/Resources/"

codesign --force --sign - "$APP_BUNDLE"
codesign --verify --strict "$APP_BUNDLE"

# SwiftPM has shipped the resource bundle both flat and wrapped in
# Contents/Resources depending on version, so accept either — the same reason
# StoryLibrary.storyRootURL() tries two paths at runtime.
BUNDLED_RESOURCES="$APP_BUNDLE/Contents/Resources/$RESOURCE_BUNDLE"
for dir in "${REQUIRED_RESOURCE_DIRS[@]}"; do
  if [ ! -d "$BUNDLED_RESOURCES/$dir" ] && [ ! -d "$BUNDLED_RESOURCES/Contents/Resources/$dir" ]; then
    echo "error: assembled bundle is missing Resources/$dir — refusing to ship it." >&2
    exit 1
  fi
done

echo "$APP_BUNDLE"
