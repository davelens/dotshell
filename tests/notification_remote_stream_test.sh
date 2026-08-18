#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$REPO_ROOT/modules/notifications/bin/remote-stream"
DSHELL="$REPO_ROOT/bin/dshell"
SANDBOX="$(mktemp -d)"
export XDG_CONFIG_HOME="$SANDBOX/config"
export XDG_DATA_HOME="$SANDBOX/data"
mkdir -p "$XDG_CONFIG_HOME/dotshell/modules/notifications/dshell" \
  "$XDG_DATA_HOME/dotshell"
cp "$REPO_ROOT/modules/notifications/dshell/init.sh" \
  "$XDG_CONFIG_HOME/dotshell/modules/notifications/dshell/init.sh"
TESTS=0
FAILURES=0
trap 'rm -rf "$SANDBOX"' EXIT

pass() { TESTS=$((TESTS + 1)); printf 'ok %d - %s\n' "$TESTS" "$1"; }
fail() { TESTS=$((TESTS + 1)); FAILURES=$((FAILURES + 1)); printf 'not ok %d - %s\n' "$TESTS" "$1" >&2; }
assert_eq() {
  if [[ "$1" == "$2" ]]; then pass "$3"; else
    printf '  expected: %s\n  actual:   %s\n' "$1" "$2" >&2
    fail "$3"
  fi
}

FAKE_SSH="$SANDBOX/ssh"
cat >"$FAKE_SSH" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$@" >"$SSH_ARGS"
cat "$SSH_STREAM"
SH
chmod +x "$FAKE_SSH"

FAKE_NOTIFY="$SANDBOX/notify-send"
cat >"$FAKE_NOTIFY" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$@" >"$NOTIFY_ARGS"
SH
chmod +x "$FAKE_NOTIFY"

{
  printf '%s\n' '{"version":1,"appName":"Pi","summary":"Ready","body":"Input needed","urgency":"critical"}'
  printf '%s\n' 'not json'
  printf '%s\n' '{"version":2,"appName":"Pi","summary":"Wrong version","body":"","urgency":"normal"}'
  printf '%s\n' '{"version":1,"appName":"Pi","summary":"Wrong urgency","body":"","urgency":"urgent"}'
} >"$SANDBOX/stream"

SSH_BIN="$FAKE_SSH" NOTIFY_BIN="$FAKE_NOTIFY" SSH_ARGS="$SANDBOX/ssh-args" \
  SSH_STREAM="$SANDBOX/stream" NOTIFY_ARGS="$SANDBOX/notify-args" \
  "$SCRIPT" devbox

mapfile -t NOTIFY_ARGS <"$SANDBOX/notify-args"
assert_eq 9 "${#NOTIFY_ARGS[@]}" 'only the valid payload invokes notify-send once'
assert_eq critical "${NOTIFY_ARGS[1]}" 'urgency is preserved'
assert_eq 'Pi @ devbox' "${NOTIFY_ARGS[3]}" 'remote source is visible in the app name'
assert_eq 'string:x-dotshell-forwarded-from:devbox' "${NOTIFY_ARGS[5]}" 'forward marker prevents loops'
assert_eq Ready "${NOTIFY_ARGS[7]}" 'summary is forwarded'
assert_eq 'Input needed' "${NOTIFY_ARGS[8]}" 'body is forwarded'

SSH_ARGS_CONTENT="$(cat "$SANDBOX/ssh-args")"
for opt in BatchMode=yes ClearAllForwardings=yes ForwardAgent=no ForwardX11=no Tunnel=no ConnectTimeout=5; do
  if grep -qxF "$opt" <<<"$SSH_ARGS_CONTENT"; then pass "ssh gets -o $opt"; else fail "ssh gets -o $opt"; fi
done
# The expressions are intentionally expanded by the remote shell.
# shellcheck disable=SC2016
if grep -qF '${XDG_BIN_HOME:-$HOME/.local/bin}/dshell' <<<"$SSH_ARGS_CONTENT" \
    && grep -qF 'notifications listen' <<<"$SSH_ARGS_CONTENT"; then
  pass 'remote command uses installed dshell and notification IPC'
else
  fail 'remote command uses installed dshell and notification IPC'
fi

status=0
"$SCRIPT" >/dev/null 2>&1 || status=$?
assert_eq 64 "$status" 'missing host exits 64'
status=0
SSH_BIN="$FAKE_SSH" NOTIFY_BIN="$FAKE_NOTIFY" "$SCRIPT" '-oProxyCommand=evil' >/dev/null 2>&1 || status=$?
assert_eq 64 "$status" 'option-shaped host exits 64'

FAKE_QS="$SANDBOX/qs"
cat >"$FAKE_QS" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$@" >"$QS_ARGS"
SH
chmod +x "$FAKE_QS"
PATH="$SANDBOX:$PATH" QS_ARGS="$SANDBOX/qs-args" "$DSHELL" notifications listen
if grep -qxF listen "$SANDBOX/qs-args" && grep -qxF notifications "$SANDBOX/qs-args" \
    && grep -qxF received "$SANDBOX/qs-args"; then
  pass 'dshell notifications listen subscribes to received events'
else
  fail 'dshell notifications listen subscribes to received events'
fi

PATH="$SANDBOX:$PATH" QS_ARGS="$SANDBOX/qs-args" "$DSHELL" notifications remote set devbox
if grep -qxF call "$SANDBOX/qs-args" && grep -qxF setRemoteHost "$SANDBOX/qs-args" \
    && grep -qxF devbox "$SANDBOX/qs-args"; then
  pass 'dshell notifications remote set updates the SSH host through IPC'
else
  fail 'dshell notifications remote set updates the SSH host through IPC'
fi

PATH="$SANDBOX:$PATH" QS_ARGS="$SANDBOX/qs-args" "$DSHELL" notifications remote clear
if grep -qxF call "$SANDBOX/qs-args" && grep -qxF clearRemoteHost "$SANDBOX/qs-args"; then
  pass 'dshell notifications remote clear clears the SSH host through IPC'
else
  fail 'dshell notifications remote clear clears the SSH host through IPC'
fi

assert_eq $'clear\nset' "$($DSHELL --complete notifications remote)" \
  'completion includes remote notification commands'

printf '1..%d\n' "$TESTS"
if [[ "$FAILURES" -gt 0 ]]; then
  printf '%d of %d tests failed\n' "$FAILURES" "$TESTS" >&2
  exit 1
fi
