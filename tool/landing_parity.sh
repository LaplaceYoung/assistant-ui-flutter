#!/usr/bin/env bash
# One command for the landing parity check:
#
#   tool/landing_parity.sh
#
# Builds the replica, serves it without the Flutter service worker (which would
# otherwise hand the browser the previous bundle), captures the live page and
# the replica frame by frame over CDP, then composes the pairs and writes
# doc/landing/parity/REPORT.md.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PORT="${PORT:-8181}"
CDP_PORT="${CDP_PORT:-9401}"
OUT="${OUT:-doc/landing/parity}"
CHROME="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
PROFILE="$(mktemp -d)"
export PATH="$HOME/development/flutter/bin:$PATH"

echo "== build =="
(cd landing && flutter build web --release >/dev/null)
# The service worker serves the previous main.dart.js; the check would silently
# measure stale code.
rm -f landing/build/web/flutter_service_worker.js

echo "== serve $PORT =="
python3 -m http.server "$PORT" --bind 127.0.0.1 --directory landing/build/web >/tmp/parity-server.log 2>&1 &
SERVER_PID=$!
cleanup() {
  kill "$SERVER_PID" 2>/dev/null || true
  if [[ -n "${CHROME_PID:-}" ]]; then
    kill "$CHROME_PID" 2>/dev/null || true
    wait "$CHROME_PID" 2>/dev/null || true
  fi
  rm -rf "$PROFILE" 2>/dev/null || true
}
trap cleanup EXIT
sleep 1

echo "== chrome :$CDP_PORT =="
"$CHROME" --headless=new --remote-debugging-port="$CDP_PORT" \
  --user-data-dir="$PROFILE" --window-size="$((1280 + 20)),$((1000 + 40))" \
  --hide-scrollbars --force-device-scale-factor=1 about:blank >/tmp/parity-chrome.log 2>&1 &
CHROME_PID=$!
for _ in $(seq 1 40); do
  curl -sf "http://127.0.0.1:$CDP_PORT/json/version" >/dev/null && break
  sleep 0.5
done

echo "== capture =="
mkdir -p "$OUT"
bun tool/landing_parity_capture.mjs --port "$PORT" --cdp "$CDP_PORT" --out "$OUT" --replica "http://127.0.0.1:$PORT/"

echo "== compose + diff =="
python3 tool/landing_parity_diff.py --dir "$OUT"

echo "report: $OUT/REPORT.md  pairs: $OUT/side_*.png"
