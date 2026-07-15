#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ORIGINAL_PATH="$PATH"
TESTS=0
FAILURES=0
SANDBOX=""
RUN_OUTPUT=""
RUN_STATUS=0

cleanup() {
  [[ -z "$SANDBOX" ]] || rm -rf "$SANDBOX"
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

assert_status() {
  local expected="$1"
  local label="$2"
  if [[ "$RUN_STATUS" -eq "$expected" ]]; then pass "$label"; else
    printf '  expected status %s, got %s\n%s\n' "$expected" "$RUN_STATUS" "$RUN_OUTPUT" >&2
    fail "$label"
  fi
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local label="$3"
  if grep -Fq -- "$needle" <<<"$haystack"; then pass "$label"; else
    printf '  missing: %s\n  in:\n%s\n' "$needle" "$haystack" >&2
    fail "$label"
  fi
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  local label="$3"
  if grep -Fq -- "$needle" <<<"$haystack"; then
    printf '  unexpected: %s\n  in:\n%s\n' "$needle" "$haystack" >&2
    fail "$label"
  else pass "$label"; fi
}

assert_symlink() {
  local path="$1"
  local target="$2"
  local label="$3"
  if [[ -L "$path" && "$(readlink "$path")" == "$target" ]]; then pass "$label"; else
    printf '  expected %s -> %s\n' "$path" "$target" >&2
    fail "$label"
  fi
}

new_sandbox() {
  cleanup
  SANDBOX="$(mktemp -d)"
  TEST_HOME="$SANDBOX/home with spaces"
  TEST_CONFIG="$SANDBOX/config with spaces"
  TEST_DATA="$SANDBOX/data with spaces"
  TEST_RUNTIME="$SANDBOX/runtime with spaces"
  TEST_BIN_HOME="$SANDBOX/bin home with spaces"
  TEST_BIN="$SANDBOX/fake-bin"
  TEST_LOG="$SANDBOX/commands.log"
  OS_RELEASE="$SANDBOX/os-release"
  TEST_GETENT_STATUS=2
  TEST_SUDO_STATUS=0
  mkdir -p "$TEST_HOME" "$TEST_BIN"
  : >"$TEST_LOG"

  cat >"$TEST_BIN/fake-command" <<'FAKE'
#!/usr/bin/env bash
set -u
name="$(basename "$0")"
{
  printf '%s' "$name"
  for arg in "$@"; do printf ' <%s>' "$arg"; done
  printf '\n'
} >>"$TEST_LOG"
case "$name" in
  id)
    case "${1:-}" in
      -u) printf '%s\n' "${TEST_ID_UID:-1000}" ;;
      -un) printf '%s\n' "${TEST_ID_USER:-test-user}" ;;
      -nG) printf '%s\n' "${TEST_ID_GROUPS:-users}" ;;
    esac
    ;;
  getent) exit "${TEST_GETENT_STATUS:-2}" ;;
  sudo) exit "${TEST_SUDO_STATUS:-0}" ;;
  lsmod) printf '%s\n' 'i2c_dev 16384 0' ;;
  pgrep) exit 1 ;;
  sv)
    [[ "${1:-}" != status ]] || exit "${TEST_SV_STATUS:-0}"
    ;;
  pacman)
    [[ "${1:-}" != -Qi ]] || exit "${TEST_PACKAGE_QUERY_STATUS:-0}"
    ;;
  xbps-query) exit "${TEST_PACKAGE_QUERY_STATUS:-0}" ;;
esac
exit 0
FAKE
  chmod +x "$TEST_BIN/fake-command"
  local command
  for command in id sudo pacman paru xbps-install xbps-query xbps-remove usermod \
    getent lsmod modprobe tee systemctl chpst sv update-desktop-database pgrep; do
    ln -s fake-command "$TEST_BIN/$command"
  done
}

set_distro() {
  printf 'ID=%s\n' "$1" >"$OS_RELEASE"
}

run_setup() {
  set +e
  RUN_OUTPUT="$(env \
    HOME="$TEST_HOME" \
    XDG_CONFIG_HOME="$TEST_CONFIG" \
    XDG_DATA_HOME="$TEST_DATA" \
    XDG_BIN_HOME="$TEST_BIN_HOME" \
    DOTSHELL_OS_RELEASE="$OS_RELEASE" \
    TEST_LOG="$TEST_LOG" \
    TEST_GETENT_STATUS="$TEST_GETENT_STATUS" \
    TEST_SUDO_STATUS="$TEST_SUDO_STATUS" \
    PATH="$TEST_BIN:$ORIGINAL_PATH" \
    bash "$REPO_ROOT/setup/init.sh" 2>&1)"
  RUN_STATUS=$?
  set -e
}

run_uninstall() {
  set +e
  RUN_OUTPUT="$(printf 'y\n' | env \
    HOME="$TEST_HOME" \
    XDG_CONFIG_HOME="$TEST_CONFIG" \
    XDG_DATA_HOME="$TEST_DATA" \
    XDG_RUNTIME_DIR="$TEST_RUNTIME" \
    DOTSHELL_OS_RELEASE="$OS_RELEASE" \
    TEST_LOG="$TEST_LOG" \
    PATH="$TEST_BIN:$ORIGINAL_PATH" \
    bash "$REPO_ROOT/setup/uninstall.sh" 2>&1)"
  RUN_STATUS=$?
  set -e
}

printf 'TAP version 13\n'

# Arch setup: exercise the complete production script twice to prove reruns are safe.
new_sandbox
set_distro arch
run_setup
assert_status 0 'Arch setup succeeds with isolated commands'
assert_contains "$(cat "$TEST_LOG")" 'sudo <pacman> <-S> <--needed> <--noconfirm>' 'Arch installs dependencies without upgrading the system'
assert_contains "$(cat "$TEST_LOG")" '<pacman-contrib>' 'Arch package list includes update support'
assert_contains "$(cat "$TEST_LOG")" 'paru <-S> <--needed> <--noconfirm> <quickshell>' 'Arch installs Quickshell through paru'
assert_contains "$(cat "$TEST_LOG")" 'systemctl <--user> <disable> <--now> <quickshell.service>' 'Arch disables the legacy systemd user service'
assert_contains "$(cat "$TEST_LOG")" 'systemctl <--user> <enable>' 'Arch enables the systemd user service'
assert_contains "$(cat "$TEST_LOG")" 'systemctl <--user> <restart> <dotshell.service>' 'Arch restarts the dotshell systemd user service'
assert_symlink "$TEST_CONFIG/dotshell" "$REPO_ROOT" 'Arch setup links the repository at a path containing spaces'
assert_symlink "$TEST_BIN_HOME/dshell" "$REPO_ROOT/bin/dshell" 'Arch setup installs dshell in XDG_BIN_HOME'
assert_symlink "$TEST_DATA/bash-completion/completions/dshell" "$REPO_ROOT/bin/dshell-completion.bash" 'Arch setup installs completion'
assert_contains "$(cat "$TEST_DATA/applications/dotshell-settings.desktop")" "Exec=qs -p \"$TEST_CONFIG/dotshell\" ipc call settings toggle" 'desktop entry quotes a config path containing spaces'
run_setup
assert_status 0 'Arch setup is idempotent'

# Arch setup: package failures explain the safe recovery without forcing an upgrade.
new_sandbox
set_distro arch
TEST_SUDO_STATUS=1
run_setup
assert_status 1 'Arch setup stops when pacman fails'
assert_contains "$RUN_OUTPUT" 'Arch does not support partial upgrades.' 'Arch package failure explains the dependency conflict'
assert_contains "$RUN_OUTPUT" 'sudo pacman -Syu' 'Arch package failure suggests an explicit full upgrade'
assert_not_contains "$(cat "$TEST_LOG")" 'paru <-S>' 'Arch setup stops before installing Quickshell after pacman fails'

# Void setup: verify XBPS, group setup, and turnstile/runit service wiring.
new_sandbox
set_distro void
TEST_GETENT_STATUS=0
run_setup
assert_status 0 'Void setup succeeds with isolated commands'
assert_contains "$(cat "$TEST_LOG")" 'sudo <xbps-install> <-Sy> <quickshell>' 'Void installs Quickshell through XBPS'
assert_contains "$(cat "$TEST_LOG")" '<NetworkManager>' 'Void uses the distribution package name for NetworkManager'
assert_contains "$(cat "$TEST_LOG")" 'sudo <usermod> <-aG> <network> <test-user>' 'Void grants the network group'
assert_contains "$(cat "$TEST_LOG")" 'sudo <usermod> <-aG> <bluetooth> <test-user>' 'Void grants the bluetooth group'
assert_symlink "$TEST_HOME/.config/service/dotshell/run" "$REPO_ROOT/setup/dotshell.run" 'Void installs the runit service'
assert_contains "$(cat "$TEST_LOG")" 'sv <status>' 'Void checks whether runit already supervises the service'
assert_contains "$(cat "$TEST_LOG")" 'sv <restart>' 'Void restarts an already supervised service'
run_setup
assert_status 0 'Void setup is idempotent'

# Unsupported and unsafe invocations must stop before side effects.
new_sandbox
set_distro debian
run_setup
assert_status 1 'unsupported distributions are rejected'
assert_contains "$RUN_OUTPUT" "unsupported distribution 'debian'" 'unsupported distribution error is actionable'
assert_not_contains "$(cat "$TEST_LOG")" 'sudo <' 'unsupported distribution performs no privileged command'
if [[ ! -e "$TEST_CONFIG/dotshell" ]]; then
  pass 'unsupported distribution creates no config link'
else
  fail 'unsupported distribution creates no config link'
fi

new_sandbox
set_distro arch
set +e
RUN_OUTPUT="$(env \
  HOME="$TEST_HOME" \
  XDG_CONFIG_HOME="$TEST_CONFIG" \
  XDG_DATA_HOME="$TEST_DATA" \
  XDG_BIN_HOME="$TEST_BIN_HOME" \
  DOTSHELL_OS_RELEASE="$OS_RELEASE" \
  TEST_LOG="$TEST_LOG" \
  TEST_ID_UID=0 \
  PATH="$TEST_BIN:$ORIGINAL_PATH" \
  bash "$REPO_ROOT/setup/init.sh" 2>&1)"
RUN_STATUS=$?
set -e
assert_status 1 'root invocation is rejected'
assert_contains "$RUN_OUTPUT" 'run this script as your desktop user' 'root error explains the remedy'
assert_not_contains "$(cat "$TEST_LOG")" 'sudo <' 'root rejection performs no privileged command'

# Uninstall exercises each platform branch against temporary user data only.
new_sandbox
set_distro arch
mkdir -p "$TEST_CONFIG" "$TEST_DATA/dotshell" "$TEST_DATA/applications" "$TEST_RUNTIME"
ln -s "$REPO_ROOT" "$TEST_CONFIG/dotshell"
printf 'fixture\n' >"$TEST_DATA/applications/dotshell-settings.desktop"
run_uninstall
assert_status 0 'Arch uninstall succeeds in an isolated home'
assert_contains "$(cat "$TEST_LOG")" 'systemctl <--user> <disable> <quickshell.service>' 'Arch uninstall disables its service'
assert_contains "$(cat "$TEST_LOG")" 'sudo <pacman> <-Rns> <--noconfirm> <quickshell-git>' 'Arch uninstall removes an installed Quickshell package'
if [[ ! -e "$TEST_CONFIG/dotshell" && ! -e "$TEST_DATA/dotshell" ]]; then
  pass 'Arch uninstall removes user files'
else
  fail 'Arch uninstall removes user files'
fi

new_sandbox
set_distro void
mkdir -p "$TEST_HOME/.config/service/dotshell" "$TEST_HOME/.config/service/quickshell" \
  "$TEST_CONFIG" "$TEST_DATA/dotshell" "$TEST_DATA/applications" "$TEST_RUNTIME"
ln -s "$REPO_ROOT/setup/dotshell.run" "$TEST_HOME/.config/service/dotshell/run"
ln -s "$REPO_ROOT" "$TEST_CONFIG/dotshell"
printf 'fixture\n' >"$TEST_DATA/applications/dotshell-settings.desktop"
run_uninstall
assert_status 0 'Void uninstall succeeds in an isolated home'
assert_contains "$(cat "$TEST_LOG")" 'sv <down>' 'Void uninstall stops its runit services'
assert_contains "$(cat "$TEST_LOG")" 'sudo <xbps-remove> <-y> <quickshell>' 'Void uninstall removes Quickshell through XBPS'
if [[ ! -e "$TEST_HOME/.config/service/dotshell" && ! -e "$TEST_HOME/.config/service/quickshell" ]]; then
  pass 'Void uninstall removes current and legacy service directories'
else
  fail 'Void uninstall removes current and legacy service directories'
fi

printf '1..%d\n' "$TESTS"
if [[ "$FAILURES" -ne 0 ]]; then
  printf '%d test(s) failed\n' "$FAILURES" >&2
  exit 1
fi
