#!/usr/bin/env bash
#
# Single-flight guard for `task dev`. `task --watch` starts a new `dev:run`
# on every save without waiting for or cancelling one already in flight, so
# saves close together run overlapping cycles. `swift run` execs itself into
# the built binary (one process throughout, just renamed) rather than
# spawning a child, and each cycle's own `pkill` only catches processes that
# already exist *at that instant* — it cannot stop a sibling cycle whose
# `swift run` is still mid-build and finishes (and launches its own window)
# later. Killing on the way in is not enough; only the most recent invocation
# is allowed to ever reach `swift run` at all.
#
# PID_FILE always holds the latest invocation's PID. Every invocation writes
# itself in, waits a moment for near-simultaneous siblings to do the same,
# then only proceeds if it is still the value on record — otherwise a newer
# invocation has taken over and this one steps aside silently.

set -euo pipefail

PID_FILE="${TMPDIR:-/tmp}/nslauncher-dev-run.pid"

echo "$$" > "$PID_FILE"
sleep 0.4
if [ "$(cat "$PID_FILE" 2>/dev/null)" != "$$" ]; then
  exit 0
fi

pkill -x NSLauncherApp 2>/dev/null || true
pkill -f 'swift-run NSLauncherApp' 2>/dev/null || true

exec swift run NSLauncherApp
