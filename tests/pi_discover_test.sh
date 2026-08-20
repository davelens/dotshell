#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DISCOVER="$REPO_ROOT/modules/ai-agents-monitor/bin/pi-discover"
SANDBOX="$(mktemp -d)"
launcher_pid=""
pi_pid=""

cleanup() {
  [ -z "$pi_pid" ] || kill "$pi_pid" 2>/dev/null || true
  [ -z "$launcher_pid" ] || kill "$launcher_pid" 2>/dev/null || true
  [ -z "$launcher_pid" ] || wait "$launcher_pid" 2>/dev/null || true
  rm -rf "$SANDBOX"
}
trap cleanup EXIT

work="$SANDBOX/work"
slug="--${work#/}--"
slug="${slug//\//-}"
sessions="$SANDBOX/sessions"
mkdir -p "$work" "$sessions/$slug"

session="$sessions/$slug/old.jsonl"
printf '%s\n' \
  '{"type":"session","id":"old"}' \
  '{"type":"message","timestamp":"2026-01-01T00:00:00Z","message":{"role":"assistant","stopReason":"stop","content":[{"type":"text","text":"What next?"}]}}' \
  >"$session"
touch -d '1 minute ago' "$session"

ln -s "$(command -v sleep)" "$SANDBOX/pi"
script -qefc "cd '$work' && exec '$SANDBOX/pi' 60" /dev/null >/dev/null 2>&1 &
launcher_pid=$!

for _ in {1..100}; do
  for candidate in $(pgrep -x pi 2>/dev/null || true); do
    if [ "$(readlink "/proc/$candidate/cwd" 2>/dev/null || true)" = "$work" ]; then
      pi_pid=$candidate
      break 2
    fi
  done
  sleep 0.01
done

[ -n "$pi_pid" ] || { echo 'not ok - fake Pi process did not start' >&2; exit 1; }
status=$(PI_SESSIONS_DIR="$sessions" "$DISCOVER" | awk -F '\t' -v cwd="$work" '$2 == cwd { print $4 }')
[ "$status" = idle ] || {
  printf 'not ok - blank Pi instance: expected idle, got %s\n' "${status:-missing}" >&2
  exit 1
}

echo 'ok - blank Pi instance ignores stale session state'

session="$sessions/$slug/current.jsonl"
printf '%s\n' \
  '{"type":"session","id":"current"}' \
  '{"type":"message","timestamp":"2026-01-01T00:00:00Z","message":{"role":"toolResult","toolName":"read","content":[{"type":"text","text":"done"}]}}' \
  '{"type":"message","timestamp":"2026-01-01T00:00:01Z","message":{"role":"assistant","stopReason":"toolUse","content":[{"type":"toolCall","id":"question-1","name":"ask_user_question","arguments":{}}]}}' \
  >"$session"
status=$(PI_SESSIONS_DIR="$sessions" "$DISCOVER" | awk -F '\t' -v cwd="$work" '$2 == cwd { print $4 }')
[ "$status" = input ] || {
  printf 'not ok - pending Pi question: expected input, got %s\n' "${status:-missing}" >&2
  exit 1
}

echo 'ok - pending Pi question reports input'
