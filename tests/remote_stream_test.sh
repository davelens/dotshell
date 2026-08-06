#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$REPO_ROOT/modules/ai-agents-monitor/bin/remote-stream"
DSHELL="$REPO_ROOT/bin/dshell"
TESTS=0
FAILURES=0
SANDBOX="$(mktemp -d)"

cleanup() {
  rm -rf "$SANDBOX"
}
trap cleanup EXIT

pass() {
  TESTS=$((TESTS + 1))
  printf 'ok %d - %s\n' "$TESTS" "$1"
}

fail() {
  TESTS=$((TESTS + 1))
  FAILURES=$((FAILURES + 1))
  printf 'not ok %d - %s\n' "$TESTS" "$1" >&2
}

assert_eq() {
  local expected="$1"
  local actual="$2"
  local label="$3"
  if [[ "$expected" == "$actual" ]]; then pass "$label"; else
    printf '  expected: %s\n  actual:   %s\n' "$expected" "$actual" >&2
    fail "$label"
  fi
}

assert_jq() {
  local input="$1"
  local filter="$2"
  local label="$3"
  if jq -e "$filter" >/dev/null 2>&1 <<<"$input"; then pass "$label"; else
    printf '  filter: %s\n  input:  %s\n' "$filter" "$input" >&2
    fail "$label"
  fi
}

# Fake ssh: records its argv (one argument per line) and prints the canned
# stream instead of connecting anywhere.
FAKE_SSH="$SANDBOX/fake-ssh"
cat >"$FAKE_SSH" <<'FAKE'
#!/usr/bin/env bash
printf '%s\n' "$@" >"$FAKE_SSH_ARGS"
cat "$FAKE_SSH_STREAM"
FAKE
chmod +x "$FAKE_SSH"

ARGS_FILE="$SANDBOX/ssh-args"
STREAM_FILE="$SANDBOX/stream"
LONG_PROJECT="$(printf 'p%.0s' {1..500})"
LONG_TITLE="$(printf 't%.0s' {1..500})"

# Line 1: valid payload; the second instance has an unknown provider and the
#         third an unknown status, so only the first may survive.
# Line 2: not JSON at all.
# Line 3: unknown schema version.
# Line 4: more than 256 instances.
# Line 5: valid payload with oversized fields (must be truncated).
{
  jq -nc --arg project "dotshell" '{
    version: 1, ready: true, generatedAtMs: 100,
    instances: [
      { provider: "pi", project: $project, status: "busy", sessionTitle: "<b>hi</b>\nnext",
        pid: "123", cwd: "/secret/path" },
      { provider: "evil", project: "x", status: "busy", sessionTitle: "" },
      { provider: "pi", project: "x", status: "exploded", sessionTitle: "" }
    ]
  }'
  echo 'this is not json'
  jq -nc '{ version: 2, ready: true, generatedAtMs: 101, instances: [] }'
  jq -nc '{
    version: 1, ready: true, generatedAtMs: 102,
    instances: [range(300) | { provider: "pi", project: "p", status: "idle", sessionTitle: "" }]
  }'
  jq -nc --arg project "$LONG_PROJECT" --arg title "$LONG_TITLE" '{
    version: 1, ready: true, generatedAtMs: 103,
    instances: [{ provider: "opencode", project: $project, status: "idle", sessionTitle: $title }]
  }'
  echo '{"version":1,"ready":true,"generatedAtMs":NaN,"instances":[]}'
} >"$STREAM_FILE"

OUTPUT="$(SSH_BIN="$FAKE_SSH" FAKE_SSH_ARGS="$ARGS_FILE" FAKE_SSH_STREAM="$STREAM_FILE" \
  "$SCRIPT" devbox)"

assert_eq 2 "$(wc -l <<<"$OUTPUT")" 'invalid lines and payloads are dropped'

FIRST="$(sed -n '1p' <<<"$OUTPUT")"
SECOND="$(sed -n '2p' <<<"$OUTPUT")"

assert_jq "$FIRST" '.version == 1 and .ready == true and .generatedAtMs == 100 and .source == "devbox"' \
  'valid payload passes through with source envelope intact'
assert_jq "$FIRST" '.instances | length == 1' \
  'instances with unknown provider or status are filtered out'
assert_jq "$FIRST" '.instances[0] | .source == "devbox" and .remote == true' \
  'instances are annotated with source host and remote flag'
assert_jq "$FIRST" '.instances[0] | has("pid") or has("cwd") | not' \
  'non-display fields are stripped'
assert_jq "$FIRST" '.instances[0].sessionTitle == "<b>hi</b> next"' \
  'control characters are replaced'
assert_jq "$SECOND" '.instances[0] | (.project | length) == 120 and (.sessionTitle | length) == 160' \
  'oversized fields are truncated'

SSH_ARGS="$(cat "$ARGS_FILE")"
assert_eq 'devbox' "$(sed -n '/^--$/{n;p;}' <<<"$SSH_ARGS")" \
  'host is passed as its own argv element after --'
for opt in 'BatchMode=yes' 'ClearAllForwardings=yes' 'ForwardAgent=no' \
  'ForwardX11=no' 'Tunnel=no' 'ConnectTimeout=5' 'ServerAliveInterval=15' \
  'ServerAliveCountMax=2'; do
  if grep -qxF "$opt" <<<"$SSH_ARGS"; then pass "ssh gets -o $opt"; else fail "ssh gets -o $opt"; fi
done
if grep -qF 'dshell agents current; exec dshell agents listen' <<<"$SSH_ARGS"; then
  pass 'remote command fetches then streams through dshell'
else
  fail 'remote command fetches then streams through dshell'
fi

STATUS=0
"$SCRIPT" >/dev/null 2>&1 || STATUS=$?
assert_eq 64 "$STATUS" 'missing host argument exits 64'

STATUS=0
"$SCRIPT" devbox extra >/dev/null 2>&1 || STATUS=$?
assert_eq 64 "$STATUS" 'extra arguments exit 64'

STATUS=0
SSH_BIN="$FAKE_SSH" FAKE_SSH_ARGS="$SANDBOX/unused-args" FAKE_SSH_STREAM="$STREAM_FILE" \
  "$SCRIPT" '-oProxyCommand=evil' >/dev/null 2>&1 || STATUS=$?
assert_eq 64 "$STATUS" 'option-shaped host exits 64'
if [[ ! -e "$SANDBOX/unused-args" ]]; then
  pass 'ssh is never invoked for an option-shaped host'
else
  fail 'ssh is never invoked for an option-shaped host'
fi

STATUS=0
LONG_HOST="$(printf 'h%.0s' {1..256})"
SSH_BIN="$FAKE_SSH" FAKE_SSH_ARGS="$SANDBOX/unused-args" FAKE_SSH_STREAM="$STREAM_FILE" \
  "$SCRIPT" "$LONG_HOST" >/dev/null 2>&1 || STATUS=$?
assert_eq 64 "$STATUS" 'oversized host alias exits 64'

# A stopped Quickshell Process terminates the adapter's SSH child as well.
BLOCKING_SSH="$SANDBOX/blocking-ssh"
BLOCKING_PID="$SANDBOX/blocking-ssh.pid"
cat >"$BLOCKING_SSH" <<'BLOCKING'
#!/usr/bin/env bash
printf '%s\n' "$$" >"$BLOCKING_SSH_PID"
exec sleep 300
BLOCKING
chmod +x "$BLOCKING_SSH"
SSH_BIN="$BLOCKING_SSH" BLOCKING_SSH_PID="$BLOCKING_PID" \
  "$SCRIPT" devbox >"$SANDBOX/blocking-output" 2>/dev/null &
STREAM_PID=$!
for _ in {1..100}; do
  [[ -s "$BLOCKING_PID" ]] && break
  sleep 0.01
done
CHILD_PID="$(cat "$BLOCKING_PID")"
kill "$STREAM_PID"
wait "$STREAM_PID" 2>/dev/null || true
if ! kill -0 "$CHILD_PID" 2>/dev/null; then
  pass 'stopping the adapter terminates its SSH child'
else
  kill "$CHILD_PID" 2>/dev/null || true
  fail 'stopping the adapter terminates its SSH child'
fi

# dshell exposes both IPC operations and keeps no-display selection internal.
FAKE_QS="$SANDBOX/qs"
QS_ARGS="$SANDBOX/qs-args"
cat >"$FAKE_QS" <<'QS'
#!/usr/bin/env bash
printf '%s\n' "$@" >"$FAKE_QS_ARGS"
printf '%s\n' "${FAKE_QS_OUTPUT:-}"
QS
chmod +x "$FAKE_QS"

CURRENT_OUTPUT="$(PATH="$SANDBOX:$PATH" FAKE_QS_ARGS="$QS_ARGS" \
  FAKE_QS_OUTPUT='{"version":1}' "$DSHELL" agents current)"
assert_eq '{"version":1}' "$CURRENT_OUTPUT" 'dshell agents current returns the IPC snapshot'
assert_eq '--any-display' "$(sed -n '/^ipc$/{n;p;}' "$QS_ARGS")" \
  'dshell agents current works without a display environment'
if grep -qxF 'call' "$QS_ARGS" && grep -qxF 'current' "$QS_ARGS"; then
  pass 'dshell agents current calls the agents current handler'
else
  fail 'dshell agents current calls the agents current handler'
fi

PATH="$SANDBOX:$PATH" FAKE_QS_ARGS="$QS_ARGS" FAKE_QS_OUTPUT='{"version":1}' \
  "$DSHELL" agents listen >/dev/null
if grep -qxF 'listen' "$QS_ARGS" && grep -qxF 'snapshot' "$QS_ARGS"; then
  pass 'dshell agents listen subscribes to snapshot events'
else
  fail 'dshell agents listen subscribes to snapshot events'
fi

assert_eq 'agents' "$($DSHELL --complete | grep -x agents)" \
  'dshell completion includes the agents group'

XDG_CONFIG_TEST="$SANDBOX/config"
XDG_DATA_TEST="$SANDBOX/data"
mkdir -p "$XDG_CONFIG_TEST/dotshell/modules/remote" \
  "$XDG_CONFIG_TEST/dotshell/statusbar" "$XDG_DATA_TEST/dotshell"
printf '%s\n' '{"settingsCategoryOrder":["statusbar"]}' \
  >"$XDG_DATA_TEST/dotshell/general.json"
printf '%s\n' '{"id":"remote","order":205,"components":{"settings":"Settings.qml"}}' \
  >"$XDG_CONFIG_TEST/dotshell/modules/remote/module.json"
printf '%s\n' '{"id":"statusbar","order":5,"components":{"settings":"Settings.qml"}}' \
  >"$XDG_CONFIG_TEST/dotshell/statusbar/module.json"
CATEGORY_OUTPUT="$(XDG_CONFIG_HOME="$XDG_CONFIG_TEST" XDG_DATA_HOME="$XDG_DATA_TEST" \
  "$DSHELL" --complete settings show-category)"
assert_eq 'remote' "$(grep -x remote <<<"$CATEGORY_OUTPUT")" \
  'settings completion includes manifest categories absent from persisted order'

printf '1..%d\n' "$TESTS"
if [[ "$FAILURES" -gt 0 ]]; then
  printf '%d of %d tests failed\n' "$FAILURES" "$TESTS" >&2
  exit 1
fi
