#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DSHELL="$REPO_ROOT/bin/dshell"
COMPLETION_SCRIPT="$REPO_ROOT/bin/dshell-completion.bash"
SANDBOX="$(mktemp -d)"
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
assert_contains() {
  if grep -qF "$2" <<<"$1"; then pass "$3"; else fail "$3"; fi
}
assert_not_contains() {
  if ! grep -qF "$2" <<<"$1"; then pass "$3"; else fail "$3"; fi
}

export XDG_CONFIG_HOME="$SANDBOX/config"
export XDG_DATA_HOME="$SANDBOX/data"
CONFIG_DIR="$XDG_CONFIG_HOME/dotshell"
mkdir -p "$CONFIG_DIR/modules" "$XDG_DATA_HOME/dotshell" "$SANDBOX/bin"
for init in "$REPO_ROOT"/modules/*/dshell/init.sh; do
  module="${init%/dshell/init.sh}"
  module="${module##*/}"
  mkdir -p "$CONFIG_DIR/modules/$module/dshell"
  cp "$init" "$CONFIG_DIR/modules/$module/dshell/init.sh"
done

cat >"$SANDBOX/bin/qs" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$@" >"$QS_ARGS"
printf '%s\n' "${QS_OUTPUT:-}"
SH
cat >"$SANDBOX/bin/nmcli" <<'SH'
#!/usr/bin/env bash
printf '%s\n' 'wifi active wlan0'
SH
chmod +x "$SANDBOX/bin/qs" "$SANDBOX/bin/nmcli"
ln -s "$DSHELL" "$SANDBOX/bin/dshell"
export PATH="$SANDBOX/bin:$PATH"
export QS_ARGS="$SANDBOX/qs-args"

HELP="$($DSHELL --help)"
assert_contains "$HELP" 'status-bar' 'help includes the renamed core command group'
assert_not_contains "$HELP" $'  bar ' 'help omits the old status bar command group'
assert_contains "$HELP" 'ai-agents-monitor' 'help includes installed module groups'
assert_contains "$HELP" 'system-updates' 'help includes the renamed updates module group'
assert_contains "$HELP" 'screen-recording' 'help includes the renamed recording module group'
assert_not_contains "$HELP" 'popup ' 'help omits the removed generic popup group'
if [[ ! -e "$QS_ARGS" ]]; then
  pass 'sourcing module extensions has no command side effects'
else
  fail 'sourcing module extensions has no command side effects'
fi

OUTPUT="$(QS_OUTPUT=toggled "$DSHELL" display toggle)"
assert_eq 'toggled' "$OUTPUT" 'display command dispatches through the merged registry'
assert_eq $'popup\ntoggle\ndisplay' "$(tail -n 3 "$QS_ARGS")" \
  'display toggle preserves its IPC target and function'
assert_not_contains "$HELP" 'brightness' 'display is the only brightness/display command group'

OUTPUT="$(QS_OUTPUT=14 "$DSHELL" display text-size)"
assert_eq '14' "$OUTPUT" 'display text-size queries current state'
assert_eq $'display\ncurrentTextSize' "$(tail -n 2 "$QS_ARGS")" \
  'display text-size query uses display IPC'
OUTPUT="$(QS_OUTPUT='Text size set to 16 px' "$DSHELL" display text-size 16)"
assert_eq 'Text size set to 16 px' "$OUTPUT" 'display text-size dispatches a new value'
assert_eq $'display\nsetTextSize\n16' "$(tail -n 3 "$QS_ARGS")" \
  'display text-size mutation uses display IPC'
assert_eq 'wifi active wlan0' "$($DSHELL wireless status)" \
  'module-local function handlers dispatch'
QS_OUTPUT=toggled "$DSHELL" system-updates toggle >/dev/null
assert_eq $'popup\ntoggle\nsystem-updates' "$(tail -n 3 "$QS_ARGS")" \
  'renamed module command uses the renamed popup id'
QS_OUTPUT=opened "$DSHELL" screen-recording files open >/dev/null
assert_eq $'overlay\nopen\nscreen-recording' "$(tail -n 3 "$QS_ARGS")" \
  'renamed recording command uses the renamed overlay id'

status=0
ERROR="$($DSHELL notifications dismiss 2>&1)" || status=$?
assert_eq 1 "$status" 'module command argument validation rejects missing arguments'
assert_eq 'error: usage: dshell notifications dismiss <id>' "$ERROR" \
  'module command argument validation reports generated usage'

COMPLETION="$($DSHELL --complete)"
assert_contains "$COMPLETION" 'status-bar' 'completion includes the renamed core command'
assert_contains "$COMPLETION" 'notifications' 'completion merges module commands'
assert_eq $'clear\nset' "$($DSHELL --complete notifications remote)" \
  'completion follows nested module paths'

# shellcheck disable=SC2034
_init_completion() { cur="${COMP_WORDS[COMP_CWORD]}"; }
# shellcheck source=/dev/null
source "$COMPLETION_SCRIPT"
completion_candidates() {
  COMP_WORDS=("$@")
  COMP_CWORD=$((${#COMP_WORDS[@]} - 1))
  COMPREPLY=()
  _dshell_complete
  printf '%s\n' "${COMPREPLY[@]}"
}
assert_eq 'ai-agents-monitor' "$(completion_candidates dshell ai-)" \
  'bash completion finds renamed module groups'
assert_eq 'toggle' "$(completion_candidates dshell display to)" \
  'bash completion finds display subcommands'
assert_eq 'open' "$(completion_candidates dshell screen-recording files o)" \
  'bash completion follows nested renamed module paths'

old_names_rejected=true
while IFS= read -r old_command; do
  read -ra words <<<"$old_command"
  if "$DSHELL" "${words[@]}" >/dev/null 2>&1; then
    old_names_rejected=false
  fi
done <<'OLD'
agents current
bar focus toggle
idle enable
network status
popup toggle volume
recording files open
updates toggle
OLD
if $old_names_rejected; then
  pass 'renamed command groups have no compatibility aliases'
else
  fail 'renamed command groups have no compatibility aliases'
fi

rm "$CONFIG_DIR/modules/display/dshell/init.sh"
HELP="$($DSHELL --help)"
assert_not_contains "$HELP" 'display' 'removing a module extension removes it from help'
if ! "$DSHELL" --complete | grep -qx display; then
  pass 'removing a module extension removes it from completion'
else
  fail 'removing a module extension removes it from completion'
fi
status=0
"$DSHELL" display toggle >/dev/null 2>&1 || status=$?
assert_eq 1 "$status" 'removing a module extension removes its dispatch'

printf '1..%d\n' "$TESTS"
if [[ "$FAILURES" -gt 0 ]]; then
  printf '%d of %d tests failed\n' "$FAILURES" "$TESTS" >&2
  exit 1
fi
