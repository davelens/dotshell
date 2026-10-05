#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SANDBOX="$(mktemp -d)"
parent=""
listener=""
# shellcheck disable=SC2329
cleanup() {
  [[ -z "$parent" ]] || kill "$parent" 2>/dev/null || true
  [[ -z "$listener" ]] || kill "$listener" 2>/dev/null || true
  rm -rf "$SANDBOX"
}
trap cleanup EXIT

mkdir -p "$SANDBOX/config" "$SANDBOX/bin"
ln -s "$REPO_ROOT" "$SANDBOX/config/dotshell"
export XDG_CONFIG_HOME="$SANDBOX/config"
export LISTENER_PID="$SANDBOX/listener-pid"
export PATH="$SANDBOX/bin:$PATH"

# Stand in for a quiet qs listener: no output to trigger a broken pipe.
cat >"$SANDBOX/bin/qs" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$$" >"$LISTENER_PID"
exec sleep 30
SH
chmod +x "$SANDBOX/bin/qs"

alive() {
  local state
  state="$(ps -p "$1" -o stat=)" || return 1
  [[ "$state" != Z* ]]
}

failures=0
for module in notifications ai-agents-monitor; do
  rm -f "$LISTENER_PID"
  # Model sshd owning an exec'd dshell command, then disconnecting.
  ( "$REPO_ROOT/bin/dshell" "$module" listen & wait ) &
  parent=$!
  for _ in {1..100}; do
    [[ -s "$LISTENER_PID" ]] && break
    sleep 0.01
  done
  read -r listener <"$LISTENER_PID"
  alive "$listener"
  kill "$parent"
  wait "$parent" 2>/dev/null || true
  parent=""

  for _ in {1..100}; do
    alive "$listener" || break
    sleep 0.01
  done
  if alive "$listener"; then
    echo "FAIL: $module listener survived its parent" >&2
    failures=$((failures + 1))
    kill "$listener"
  else
    echo "PASS: $module listener exits with its parent"
  fi
  listener=""
done

exit "$failures"
