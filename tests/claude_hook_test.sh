#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$REPO_ROOT/modules/ai-agents-monitor/bin/claude-hook"
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

mkdir -p "$SANDBOX/bin"
export PATH="$SANDBOX/bin:$PATH"
export XDG_RUNTIME_DIR="$SANDBOX/run"
export SENT="$SANDBOX/sent"

# Stand in for ncat: record its argv and the line it would send.
cat >"$SANDBOX/bin/ncat" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >"$SENT.args"
cat >"$SENT"
SH
chmod +x "$SANDBOX/bin/ncat"

# Process names come from the executable basename, so these give the hook a
# claude (or pi → claude) ancestry. The trailing `:` stops bash from exec'ing
# the hook in place of the fake parent.
ln -s "$(command -v bash)" "$SANDBOX/claude"
ln -s "$(command -v bash)" "$SANDBOX/pi"

failures=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1" >&2; failures=$((failures + 1)); }
expect_none() { if [[ -e "$SENT" ]]; then fail "$1"; else pass "$1"; fi; }

# Orphan the fake process tree so the ancestry walk never reaches whatever
# runs the tests (such as a real Pi session).
detached() {
  rm -f "$SANDBOX/done"
  ( ( "$@"; touch "$SANDBOX/done" ) & )
  for _ in {1..500}; do
    [[ -e "$SANDBOX/done" ]] && return
    sleep 0.01
  done
  fail "detached command did not finish: $*"
}

run_under_claude() {
  rm -f "$SENT"
  # shellcheck disable=SC2016
  detached "$SANDBOX/claude" -c 'printf "%s\n" "$$" >"$SENT.pid"; "$1" <<<"$2"; :' _ "$HOOK" "$1"
}

expect() {
  local payload="$1" filter="$2" label="$3"
  run_under_claude "$payload"
  if [[ -s "$SENT" ]] && jq -e --argjson pid "$(cat "$SENT.pid")" "$filter" "$SENT" >/dev/null; then
    pass "$label"
  else
    fail "$label (sent: $(cat "$SENT" 2>/dev/null || echo nothing))"
  fi
}

# shellcheck disable=SC2016
expect '{"hook_event_name":"SessionStart","cwd":"/work/proj"}' \
  '.provider == "claude-code" and .pid == $pid and .oneshot == true and .status == "idle" and .cwd == "/work/proj"' \
  'SessionStart reports idle with the claude pid and cwd'
expect '{"hook_event_name":"UserPromptSubmit","cwd":"/w","prompt":"  fix\n the   bug  "}' \
  '.status == "busy" and .title == "fix the bug"' \
  'UserPromptSubmit reports busy with a normalised prompt title'
expect "{\"hook_event_name\":\"UserPromptSubmit\",\"cwd\":\"/w\",\"prompt\":\"$(printf 'x%.0s' {1..100})\"}" \
  '.title | length == 80 and endswith("...")' \
  'long prompt titles are clipped to 80 characters'
expect '{"hook_event_name":"PreToolUse","cwd":"/w","tool_name":"Bash"}' \
  '.status == "busy" and (has("title") | not)' \
  'PreToolUse reports busy without touching the title'
expect '{"hook_event_name":"PreToolUse","cwd":"/w","tool_name":"AskUserQuestion"}' \
  '.status == "input"' 'AskUserQuestion reports input'
expect '{"hook_event_name":"PermissionRequest","cwd":"/w"}' '.status == "input"' \
  'PermissionRequest reports input'
expect '{"hook_event_name":"PostToolUse","cwd":"/w"}' '.status == "busy"' \
  'PostToolUse reports busy'
expect '{"hook_event_name":"Stop","cwd":"/w"}' '.status == "idle"' 'Stop reports idle'
expect '{"hook_event_name":"StopFailure","cwd":"/w"}' '.status == "error"' \
  'StopFailure reports error'
expect '{"hook_event_name":"SessionEnd","cwd":"/w"}' '.status == "gone"' \
  'SessionEnd reports gone'

run_under_claude '{"hook_event_name":"Notification","cwd":"/w"}'
expect_none 'unmapped events send nothing'

if grep -qx -- "-U --send-only $XDG_RUNTIME_DIR/dotshell-agents.sock" "$SENT.args"; then
  pass 'sends to the runtime-dir socket'
else
  fail "sends to the runtime-dir socket (args: $(cat "$SENT.args"))"
fi

rm -f "$SENT"
# shellcheck disable=SC2016
detached "$SANDBOX/pi" -c '"$1" -c "\"\$1\" <<<\"\$2\"; :" _ "$2" "$3"; :' _ \
  "$SANDBOX/claude" "$HOOK" '{"hook_event_name":"Stop","cwd":"/w"}'
expect_none 'Pi-driven Claude sends nothing'

rm -f "$SENT"
# shellcheck disable=SC2016
detached bash -c '"$1" <<<"$2"; :' _ "$HOOK" '{"hook_event_name":"Stop","cwd":"/w"}'
expect_none 'no claude ancestor sends nothing'

exit "$failures"
