#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script="$repo_root/modules/bluetooth/bin/bluetooth-device"
sandbox="$(mktemp -d)"
trap 'rm -rf "$sandbox"' EXIT

export CALL_LOG="$sandbox/calls"
mkdir -p "$sandbox/bin" "$sandbox/tmp"
: >"$CALL_LOG"

cat >"$sandbox/bin/bluetoothctl" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$CALL_LOG"
if [[ ${FAIL_COMMAND:-} == "$1" ]]; then
  if [[ ${FAIL_MODE:-} == not-connected ]]; then
    printf 'Failed to disconnect: org.bluez.Error.NotConnected\n'
  else
    printf 'Failed to %s: test failure\n' "$1"
  fi
  exit "${FAIL_STATUS:-0}"
fi
printf 'Successful %s\n' "$1"
SH
chmod +x "$sandbox/bin/bluetoothctl"
export PATH="$sandbox/bin:$PATH"
export TMPDIR="$sandbox/tmp"

address='AA:bb:01:23:45:67'

"$script" pair "$address" >/dev/null
[[ $(cat "$CALL_LOG") == $'pair AA:bb:01:23:45:67\ntrust AA:bb:01:23:45:67\nconnect AA:bb:01:23:45:67' ]]
printf 'ok - pair runs pair, trust, and connect in order\n'

: >"$CALL_LOG"
status=0
output="$(FAIL_COMMAND=trust "$script" connect "$address")" || status=$?
[[ $status -ne 0 ]]
[[ $output == *'Failed to trust: test failure'* ]]
[[ $(cat "$CALL_LOG") == 'trust AA:bb:01:23:45:67' ]]
printf 'ok - stdout failures stop an operation even with a zero exit status\n'

: >"$CALL_LOG"
"$script" disconnect "$address" >/dev/null
[[ $(cat "$CALL_LOG") == 'disconnect AA:bb:01:23:45:67' ]]
printf 'ok - disconnect runs bluetoothctl disconnect\n'

: >"$CALL_LOG"
FAIL_COMMAND=disconnect FAIL_MODE=not-connected FAIL_STATUS=1 \
  "$script" forget "$address" >/dev/null
[[ $(cat "$CALL_LOG") == $'disconnect AA:bb:01:23:45:67\nremove AA:bb:01:23:45:67' ]]
printf 'ok - forget removes a device that is already disconnected\n'

: >"$CALL_LOG"
status=0
"$script" pair 'not-a-mac' >/dev/null 2>&1 || status=$?
[[ $status -eq 2 && ! -s $CALL_LOG ]]
printf 'ok - invalid Bluetooth addresses are rejected\n'
