#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
manager="$repo_root/modules/bluetooth/Manager.qml"
popup="$repo_root/modules/bluetooth/Popup.qml"
settings="$repo_root/modules/bluetooth/Settings.qml"

assert_contains() {
  local text="$1"
  grep -Fq -- "$text" "$manager" || {
    printf 'Bluetooth manager contract missing: %s\n' "$text" >&2
    exit 1
  }
}

assert_popup_contains() {
  local text="$1"
  grep -Fq -- "$text" "$popup" || {
    printf 'Bluetooth popup contract missing: %s\n' "$text" >&2
    exit 1
  }
}

assert_settings_contains() {
  local text="$1"
  grep -Fq -- "$text" "$settings" || {
    printf 'Bluetooth settings contract missing: %s\n' "$text" >&2
    exit 1
  }
}

assert_contains 'import Quickshell.Bluetooth'
assert_contains 'Bluetooth.defaultAdapter'
assert_contains 'Bluetooth.devices.values'
for property in connected paired bonded trusted; do
  assert_contains "device.$property"
done
printf 'ok - adapter and device state come from Quickshell.Bluetooth\n'

assert_contains 'known ? "connect" : "pair"'
for operation in pair connect disconnect forget; do
  assert_contains "\"$operation\""
done
assert_contains 'stdout: StdioCollector {}'
assert_contains 'stderr: StdioCollector {}'
assert_contains 'connectErrorAddress = operation.address'
assert_contains '_operations'
printf 'ok - helper operations are serialized and report captured errors\n'

assert_contains '["rfkill", "block", "bluetooth"]'
assert_contains '["rfkill", "unblock", "bluetooth"]'
assert_contains '["bluetoothctl", "power", "on"]'
assert_contains 'moduleId: "bluetooth"'
assert_contains 'scope: "general"'
assert_contains 'property string powerPreference: ""'
assert_contains 'powerPreference = "off"'
assert_contains 'powerPreference = "on"'
assert_contains 'function _restorePowerPreference()'
if grep -Fq '["bash"' "$manager"; then
  printf 'Bluetooth manager must use direct process argv\n' >&2
  exit 1
fi
if [[ $(grep -Fc '"bluetoothctl"' "$manager") -ne 1 ]]; then
  printf 'bluetoothctl must only be used for the power-on fallback\n' >&2
  exit 1
fi
printf 'ok - radio commands use direct argv with portable persisted state and a bounded fallback\n'

assert_contains 'function startScan(continuous = false)'
assert_contains '_setDiscovering(true)'
assert_contains '_setDiscovering(false)'
assert_contains 'boundedScanTimer.restart()'
assert_contains '!bluetoothManager._scanRequested'
assert_contains 'function stopScan()'
scan_function="$(sed -n '/^  function startScan(/,/^  }/p' "$manager")"
grep -Fq '_scanRequested = true' <<<"$scan_function"
if grep -Fq 'if (!adapter || !powered) return' <<<"$scan_function"; then
  printf 'Continuous scan requests must survive an unavailable or powered-off adapter\n' >&2
  exit 1
fi
assert_contains 'bluetoothManager._continuousScan && bluetoothManager.powered'
assert_contains 'bluetoothManager._applyScanRequest()'
printf 'ok - scan requests survive power changes, restart continuously, and stop late starts\n'

assert_contains 'property string globalError: ""'
assert_contains 'bluetoothManager.globalError = bluetoothManager._globalErrorMessage(operation, output)'
assert_contains 'globalError = "Could not enable Bluetooth."'
assert_contains 'scanConfirmationTimer.restart()'
assert_contains 'globalError = "Could not start Bluetooth discovery."'
assert_contains 'bluetoothManager.globalError = ""'
assert_contains 'if (!address || busy) return'
assert_contains 'property string deviceAction: ""'
assert_contains 'property string connectErrorAction: ""'
printf 'ok - radio failures and serialized device action state are exposed to UI\n'

assert_popup_contains 'BluetoothManager.clearErrors()'
assert_popup_contains 'BluetoothManager.startScan(true)'
assert_popup_contains 'BluetoothManager.stopScan()'
assert_popup_contains 'modelData.paired || modelData.bonded || modelData.trusted'
if [[ $(grep -Fc 'BluetoothManager.forget(modelData.address)' "$popup") -lt 2 ]]; then
  printf 'Bluetooth popup must offer forget for connected and available known devices\n' >&2
  exit 1
fi
for text in 'Pairing...' 'Connecting...' 'Disconnecting...' 'Forgetting...'; do
  assert_popup_contains "$text"
done
assert_popup_contains 'BluetoothManager.connectErrorAddress === modelData.address'
assert_popup_contains 'BluetoothManager.globalError'
assert_popup_contains 'FocusListItem {'
assert_popup_contains 'FocusIconButton {'
printf 'ok - popup owns scanning and exposes primary, forget, busy, and error states\n'

assert_settings_contains 'onClicked: BluetoothManager.startScan(false)'
if grep -Fq 'BluetoothManager.startScan(true)' "$settings"; then
  printf 'Bluetooth settings discovery must remain bounded\n' >&2
  exit 1
fi
assert_settings_contains 'modelData.paired || modelData.bonded || modelData.trusted'
if [[ $(grep -Fc 'BluetoothManager.forget(modelData.address)' "$settings") -lt 2 ]]; then
  printf 'Bluetooth settings must offer forget for connected and available known devices\n' >&2
  exit 1
fi
for text in 'Pairing...' 'Connecting...' 'Disconnecting...' 'Forgetting...'; do
  assert_settings_contains "$text"
done
if [[ $(grep -Fc 'BluetoothManager.connectErrorAddress === modelData.address' "$settings") -lt 2 ]]; then
  printf 'Bluetooth settings must show errors under connected and available devices\n' >&2
  exit 1
fi
assert_settings_contains 'BluetoothManager.globalError'
if [[ $(grep -Fc 'enabled: !BluetoothManager.busy' "$settings") -lt 6 ]]; then
  printf 'Bluetooth settings must disable conflicting controls while busy\n' >&2
  exit 1
fi
if [[ $(grep -Fc 'FocusLink {' "$settings") -lt 3 ]] \
    || [[ $(grep -Fc 'text: "Forget"' "$settings") -lt 2 ]]; then
  printf 'Bluetooth settings forget actions must be distinct keyboard-focusable controls\n' >&2
  exit 1
fi
printf 'ok - settings uses bounded discovery and exposes primary, forget, busy, and error states\n'

for function_name in clearErrors togglePower startScan stopScan connect disconnect forget; do
  assert_contains "function $function_name("
done
printf 'ok - Bluetooth manager public operation API is preserved\n'
