#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DISCOVER="${DISCOVER:-$REPO_ROOT/modules/ai-agents-monitor/bin/pi-discover}"
SANDBOX="$(mktemp -d)"
launchers=()
pids=()
cleanup() {
  for pid in "${pids[@]}" "${launchers[@]}"; do kill "$pid" 2>/dev/null || true; done
  for pid in "${launchers[@]}"; do wait "$pid" 2>/dev/null || true; done
  rm -rf "$SANDBOX"
}
trap cleanup EXIT

work="$SANDBOX/work"
slug="--${work#/}--"
slug="${slug//\//-}"
export PI_SESSIONS_DIR="$SANDBOX/sessions" # Only the pre-fix regression uses this.
export PI_AGENT_STATE_DIR="$SANDBOX/state"
mkdir -p "$work" "$PI_SESSIONS_DIR/$slug" "$PI_AGENT_STATE_DIR"
ln -s "$(command -v sleep)" "$SANDBOX/pi"

start_pi() {
  script -qefc "cd '$work' && exec '$SANDBOX/pi' 120" /dev/null >/dev/null 2>&1 &
  launchers+=("$!")
  local candidate
  for _ in {1..100}; do
    for candidate in $(pgrep -x pi 2>/dev/null || true); do
      if [[ " ${pids[*]} " != *" $candidate "* ]] \
          && [ "$(readlink "/proc/$candidate/cwd" 2>/dev/null || true)" = "$work" ]; then
        pids+=("$candidate")
        return
      fi
    done
    sleep 0.01
  done
  echo 'not ok - fake Pi process did not start' >&2
  exit 1
}

register() {
  local stat ticks
  local -a fields
  stat=$(cat "/proc/$1/stat")
  read -r -a fields <<<"${stat##*) }"
  ticks=${fields[19]}
  jq -nc --argjson pid "$1" --arg ticks "$ticks" \
    --arg boot "$(cat /proc/sys/kernel/random/boot_id)" --arg id "$2" --arg file "$3" \
    '{version:1, pid:$pid, startTicks:$ticks, bootId:$boot, sessionId:$id,
      sessionFile:(if $file == "" then null else $file end)}' >"$PI_AGENT_STATE_DIR/$1.json"
}

assert_row() {
  local actual
  actual=$("$DISCOVER" | awk -F '\t' -v pid="$1" '$1 == pid')
  if [ "$actual" != "$2" ]; then
    printf 'not ok - %s\n  expected: %s\n  actual: %s\n' "$3" "$2" "$actual" >&2
    exit 1
  fi
  printf 'ok - %s\n' "$3"
}

name='Infrastructure > Docker > Build development bootstrap with MySQL and production imports'
old="$PI_SESSIONS_DIR/$slug/old.jsonl"
printf '%s\n' \
  '{"type":"session","id":"old"}' \
  '{"type":"message","message":{"role":"user","content":[{"type":"text","text":"Original prompt, not the name"}]}}' \
  '{"type":"session_info","name":"Previous name"}' \
  "$(jq -nc --arg name "$name" '{type:"session_info",name:$name}')" \
  '{"type":"session_info","name":"  "}' \
  '{"type":"message","timestamp":"2026-01-01T00:00:00Z","message":{"role":"assistant","stopReason":"stop","content":[{"type":"text","text":"What next?"}]}}' >"$old"
touch -d '1 minute ago' "$old"
start_pi
pi_pid=${pids[0]}
register "$pi_pid" old "$old"
printf '%s\n' \
  '{"type":"session","id":"unrelated"}' \
  '{"type":"message","message":{"role":"user","content":[{"type":"text","text":"scc conversation"}]}}' \
  >"$PI_SESSIONS_DIR/$slug/newer.jsonl"
touch -d '1 minute' "$PI_SESSIONS_DIR/$slug/newer.jsonl"
expected="$pi_pid"$'\t'"$work"$'\told\tinput\t'"$name"
assert_row "$pi_pid" "$expected" 'same PID keeps older resumed named session despite newer unrelated scc file'
[ "${1:-}" != --regression-only ] || exit 0

printf '%s\n' '{"type":"session_info","name":"Renamed inactive session"}' >>"$PI_SESSIONS_DIR/$slug/newer.jsonl"
assert_row "$pi_pid" "$expected" 'renaming an inactive session cannot change attribution'

# A second session can live anywhere; its older mtime cannot swap the two PIDs.
current="$SANDBOX/arbitrary session.jsonl"
printf '%s\n' \
  '{"type":"session","id":"current"}' \
  '{"type":"message","timestamp":"2026-01-01T00:00:00Z","message":{"role":"toolResult","content":[]}}' \
  '{"type":"message","timestamp":"2026-01-01T00:00:01Z","message":{"role":"assistant","stopReason":"toolUse","content":[{"type":"toolCall","id":"question-1","name":"ask_user_question","arguments":{}}]}}' >"$current"
start_pi
pi_pid2=${pids[1]}
register "$pi_pid2" current "$current"
touch -d '2 minutes ago' "$current"
assert_row "$pi_pid" "$expected" 'same-cwd first PID retains its exact file'
assert_row "$pi_pid2" "$pi_pid2"$'\t'"$work"$'\tcurrent\tinput\t' 'same-cwd second PID uses arbitrary file location, not mtime'
printf '%s\n' '{"type":"message","timestamp":"2026-01-01T00:00:02Z","message":{"role":"toolResult","toolCallId":"question-1","content":[]}}' >>"$current"
assert_row "$pi_pid2" "$pi_pid2"$'\t'"$work"$'\tcurrent\tbusy\t' 'resolved question preserves busy inference by PID'

record="$PI_AGENT_STATE_DIR/$pi_pid.json"
cp "$record" "$SANDBOX/valid.json"
for mutation in '.version=2' '.pid+=1' '.startTicks="0"' '.bootId="stale"' \
  '.sessionId="wrong-header"' '.sessionId=42' '.sessionId=""' '.sessionId="bad\tfield"' \
  '.sessionFile=42' '.sessionFile="relative.jsonl"' 'del(.sessionFile)' \
  '.sessionFile="/nonexistent/dotshell-session.jsonl"' '.startTicks=42' '[]'; do
  jq "$mutation" "$SANDBOX/valid.json" >"$record"
  assert_row "$pi_pid" '' "invalid record omitted: $mutation"
  [ -f "$record" ] || { echo 'not ok - discovery deleted a record' >&2; exit 1; }
done
cat "$SANDBOX/valid.json" "$SANDBOX/valid.json" >"$record"
assert_row "$pi_pid" '' 'multiple JSON records are malformed, not multiple TSV rows'
printf 'malformed json\n' >"$record"
assert_row "$pi_pid" '' 'malformed record omitted'
rm "$record"
mkfifo "$record"
assert_row "$pi_pid" '' 'nonregular registry file omitted without reading it'
rm "$record"
assert_row "$pi_pid" '' 'unregistered terminal process omitted (including headless with inherited terminal)'
register "$pi_pid" ephemeral ''
assert_row "$pi_pid" "$pi_pid"$'\t'"$work"$'\tephemeral\tidle\t' 'nonpersistent session emits idle blank row without borrowing a file'
register "$pi_pid" lazy "$SANDBOX/lazy.jsonl"
assert_row "$pi_pid" '' 'not-yet-flushed file omitted'
printf '%s\n' '{"type":"session","id":"lazy"}' >"$SANDBOX/lazy.jsonl"
assert_row "$pi_pid" "$pi_pid"$'\t'"$work"$'\tlazy\tidle\t' 'lazy file becomes discoverable without republishing'
printf '%s\n' 'not a header' >"$SANDBOX/lazy.jsonl"
assert_row "$pi_pid" '' 'malformed session header omitted'

long_name="$name $(printf 'long %.0s' {1..40})end"
printf '%s\n' "$(jq -nc --arg name "$long_name" '{type:"session_info",name:$name}')" >>"$old"
register "$pi_pid" old "$old"
assert_row "$pi_pid" "$pi_pid"$'\t'"$work"$'\told\tinput\t'"$long_name" 'named title longer than 160 characters survives discovery'
printf '%s\n' '{"type":"message","message":{"role":"user","content":[{"type":"text","text":"  First\tuser\n prompt  "}]}}' >>"$SANDBOX/lazy.jsonl"
printf '%s\n' '{"type":"session","id":"prompt"}' >"$SANDBOX/prompt.jsonl"
tail -n 1 "$SANDBOX/lazy.jsonl" >>"$SANDBOX/prompt.jsonl"
register "$pi_pid" prompt "$SANDBOX/prompt.jsonl"
assert_row "$pi_pid" "$pi_pid"$'\t'"$work"$'\tprompt\tidle\tFirst user prompt' 'unnamed session keeps normalized first-prompt fallback'

long_prompt="$(printf 'prompt %.0s' {1..100})end"
printf '%s\n' '{"type":"session","id":"prompt"}' \
  "$(jq -nc --arg text "$long_prompt" '{type:"message",message:{role:"user",content:[{type:"text",text:$text}]}}')" >"$SANDBOX/prompt.jsonl"
assert_row "$pi_pid" "$pi_pid"$'\t'"$work"$'\tprompt\tidle\t'"${long_prompt:0:77}..." 'unnamed long prompt retains the 80-character fallback limit'

# Even a matching record cannot make a process with nonterminal stdin a row.
(cd "$work" && exec "$SANDBOX/pi" 120) </dev/null &
headless=$!
pids+=("$headless")
register "$headless" old "$old"
assert_row "$headless" '' 'nonterminal Pi process excluded'

fixture="$SANDBOX/guardrail.jsonl"
printf '%s\n' \
  '{"type":"message","timestamp":"2026-01-01T00:00:00Z","message":{"role":"user","content":[]}}' \
  '{"type":"message","timestamp":"2026-01-01T00:00:01Z","message":{"role":"assistant","stopReason":"toolUse","content":[{"type":"toolCall","id":"danger-1","name":"bash","arguments":{"command":"set -e\nrm -rf ./base"}}]}}' \
  >"$fixture"
status=$("$DISCOVER" --status-file "$fixture")
[ "$status" = input ] || {
  printf 'not ok - pending Pi guardrail: expected input, got %s\n' "${status:-missing}" >&2
  exit 1
}

echo 'ok - pending Pi guardrail reports input'

printf '%s\n' \
  '{"type":"message","timestamp":"2026-01-01T00:00:02Z","message":{"role":"toolResult","toolCallId":"danger-1","content":[]}}' \
  >>"$fixture"
status=$("$DISCOVER" --status-file "$fixture")
[ "$status" = busy ] || {
  printf 'not ok - resolved Pi guardrail: expected busy, got %s\n' "${status:-missing}" >&2
  exit 1
}

echo 'ok - resolved Pi guardrail no longer reports input'
