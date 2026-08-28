#!/usr/bin/env bash
#
# Builds NS Launcher, launches it, starts the game, and captures screenshots
# of the launcher window and the game's pre-login screen into Screenshots/.
#
# Requires: the game already installed via the launcher, and the terminal
# running this script granted Accessibility permission (System Events).

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$ROOT_DIR/Screenshots"
APP_NAME="NSLauncher"
GAME_WAIT_TIMEOUT=240
POLL_INTERVAL=3

mkdir -p "$OUT_DIR"

echo "==> Building and bundling $APP_NAME.app"
(cd "$ROOT_DIR" && task bundle)

BIN_PATH="$(cd "$ROOT_DIR" && swift build -c release --show-bin-path)"
APP_BUNDLE="$BIN_PATH/$APP_NAME.app"

echo "==> Closing any running instance"
osascript -e "tell application \"$APP_NAME\" to quit" >/dev/null 2>&1 || true
pkill -f "$APP_NAME" >/dev/null 2>&1 || true
sleep 1

echo "==> Launching $APP_BUNDLE"
open "$APP_BUNDLE"

echo "==> Waiting for launcher window"
for _ in $(seq 1 30); do
  if osascript -e "tell application \"System Events\" to (exists process \"$APP_NAME\") and (exists window 1 of process \"$APP_NAME\")" 2>/dev/null | grep -q true; then
    break
  fi
  sleep 1
done
sleep 1

capture_window() {
  local process_name="$1"
  local out_file="$2"
  local bounds
  bounds="$(osascript <<EOF
tell application "System Events"
  tell process "$process_name"
    set frontmost to true
    set winPos to position of window 1
    set winSize to size of window 1
  end tell
end tell
(item 1 of winPos as text) & "," & (item 2 of winPos as text) & "," & (item 1 of winSize as text) & "," & (item 2 of winSize as text)
EOF
)"
  screencapture -o -R"$bounds" "$out_file"
}

echo "==> Capturing launcher window"
capture_window "$APP_NAME" "$OUT_DIR/launcher.png"

echo "==> Clicking Play"
osascript -e "tell application \"System Events\" to tell process \"$APP_NAME\" to click button \"Play\" of window 1" >/dev/null

echo "==> Waiting for the game window (up to ${GAME_WAIT_TIMEOUT}s)"
GAME_PROCESS=""
elapsed=0
while [ "$elapsed" -lt "$GAME_WAIT_TIMEOUT" ]; do
  GAME_PROCESS="$(osascript <<'EOF' 2>/dev/null
tell application "System Events"
  set matches to {}
  repeat with p in processes
    try
      if (count of windows of p) > 0 then
        repeat with w in windows of p
          if name of w contains "Genshin" then
            return name of p
          end if
        end repeat
      end if
    end try
  end repeat
end tell
return ""
EOF
)"
  if [ -n "$GAME_PROCESS" ]; then
    break
  fi
  sleep "$POLL_INTERVAL"
  elapsed=$((elapsed + POLL_INTERVAL))
done

if [ -z "$GAME_PROCESS" ]; then
  echo "!! Timed out waiting for the game window; skipping game screenshot" >&2
else
  echo "==> Game window owned by process '$GAME_PROCESS'; capturing pre-login screen"
  sleep 3
  capture_window "$GAME_PROCESS" "$OUT_DIR/game.png"
fi

echo "==> Stopping the game and quitting the launcher"
osascript -e "tell application \"System Events\" to tell process \"$APP_NAME\" to click button \"Stop\" of window 1" >/dev/null 2>&1 || true
sleep 2
osascript -e "tell application \"$APP_NAME\" to quit" >/dev/null 2>&1 || true

echo "==> Done. Screenshots written to $OUT_DIR"
