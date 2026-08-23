#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
manager="$repo_root/modules/wireless/Manager.qml"
popup="$repo_root/modules/wireless/Popup.qml"
settings="$repo_root/modules/wireless/Settings.qml"
wireless_doc="$repo_root/docs/wiki/wireless.md"
wiki_index="$repo_root/docs/wiki/index.md"

assert_contains() {
  local text="$1"
  grep -Fq -- "$text" "$manager" || {
    printf 'Wireless manager contract missing: %s\n' "$text" >&2
    exit 1
  }
}

assert_popup_contains() {
  local text="$1"
  grep -Fq -- "$text" "$popup" || {
    printf 'Wireless popup contract missing: %s\n' "$text" >&2
    exit 1
  }
}

assert_settings_contains() {
  local text="$1"
  grep -Fq -- "$text" "$settings" || {
    printf 'Wireless settings contract missing: %s\n' "$text" >&2
    exit 1
  }
}

assert_doc_contains() {
  local text="$1"
  grep -Fq -- "$text" "$wireless_doc" || {
    printf 'Wireless documentation contract missing: %s\n' "$text" >&2
    exit 1
  }
}

assert_contains 'import Quickshell.Networking'
assert_contains 'Networking.backend === NetworkBackendType.NetworkManager'
assert_contains 'Networking.devices ? Networking.devices.values : []'
assert_contains 'device.type === DeviceType.Wifi'
assert_contains 'device.networks.values'
assert_contains 'Networking.wifiEnabled = value'
assert_contains 'devices[j].scannerEnabled = true'
assert_contains 'previous[i].scannerEnabled = false'
assert_contains 'onNativeRevisionChanged: syncNativeState()'
printf 'ok - state, radio, devices, networks, and scanners use the native NetworkManager backend\n'

assert_contains 'ListModel {'
assert_contains 'dynamicRoles: false'
assert_contains 'return JSON.stringify([device.name || "", network.name || ""])'
for role in networkKey deviceName ssid signal security secured requiresPsk known connected state stateChanging; do
  assert_contains "$role:"
done
assert_contains 'networkRows.setProperty(target, role, rows[target][role])'
if grep -Eq '(^|[[:space:]])(network|device):[[:space:]]*(network|device)(,|$)' "$manager"; then
  printf 'Wireless public model must not expose native network or device objects\n' >&2
  exit 1
fi
printf 'ok - the device-qualified network model has primitive, fixed ListModel roles\n'

for function_name in connect connectWithPsk disconnect forget; do
  assert_contains "function $function_name("
done
for native_call in 'network.connect()' 'network.connectWithPsk(password)' 'network.disconnect()' 'network.forget()'; do
  assert_contains "$native_call"
done
printf 'ok - connection operations resolve a native network and call its native API\n'

failure_mapping="$(sed -n '/^  function failureFromReason(/,/^  }/p' "$manager")"
failure_messages="$(sed -n '/^  function messageForFailure(/,/^  }/p' "$manager")"
for reason in WifiAuthTimeout NoSecrets WifiClientDisconnected WifiNetworkLost WifiClientFailed Unknown; do
  grep -Fq "ConnectionFailReason.$reason" <<<"$failure_mapping" || {
    printf 'Wireless failure-code mapping missing ConnectionFailReason.%s\n' "$reason" >&2
    exit 1
  }
  grep -Fq "FailureCode.$reason" <<<"$failure_mapping" || {
    printf 'Wireless failure-code mapping is not typed for %s\n' "$reason" >&2
    exit 1
  }
  grep -Fq "ConnectionFailReason.$reason" <<<"$failure_messages" || {
    printf 'Wireless failure message missing ConnectionFailReason.%s\n' "$reason" >&2
    exit 1
  }
done
for code in None BackendUnavailable WifiAuthTimeout NoSecrets WifiClientDisconnected WifiNetworkLost WifiClientFailed Unknown OperationTimeout; do
  assert_contains "$code"
done
assert_contains 'function onConnectionFailed(reason)'
assert_contains 'WirelessManager.FailureCode.OperationTimeout'
printf 'ok - every native connection failure reason maps to typed UI failure state\n'

assert_contains 'readonly property bool busy: actionKind !== ""'
assert_contains 'if (busy) return false'
assert_contains 'function beginAction(kind, key, network)'
assert_contains 'actionTimeout.restart()'
for kind in radio connect disconnect forget; do
  assert_contains "beginAction(\"$kind\""
done
if [[ $(grep -Fc 'id: actionTimeout' "$manager") -ne 1 ]] \
    || [[ $(grep -Fc 'interval: 30000' "$manager") -ne 1 ]]; then
  printf 'Wireless actions must share one 30-second timeout\n' >&2
  exit 1
fi
assert_contains 'repeat: false'
printf 'ok - radio and network actions are serialized behind one 30-second timeout\n'

for old_poll in statusProc networkListProc savedConnectionsProc activeDeviceProc parseNetworkList 'function refresh('; do
  if grep -Fq -- "$old_poll" "$manager"; then
    printf 'Wireless manager must not poll network state: %s\n' "$old_poll" >&2
    exit 1
  fi
done
if [[ $(grep -Fc 'Process {' "$manager") -ne 3 ]]; then
  printf 'Wireless manager must contain two uptime lookups and one throughput Process\n' >&2
  exit 1
fi
if [[ $(grep -Fc '"nmcli"' "$manager") -ne 2 ]]; then
  printf 'Wireless manager may use nmcli only for the two uptime metadata queries\n' >&2
  exit 1
fi
assert_contains '["nmcli", "-g", "GENERAL.CON-UUID", "device", "show", network.deviceName]'
assert_contains '"connection", "show", "uuid", uuid]'
assert_contains 'property real connectionTimestamp: 0'
assert_contains 'function getConnectionDurationLong()'
throughput_process="$(sed -n '/id: networkStatsProc/,/^  }/p' "$manager")"
for text in '"cat"' '/sys/class/net/' '/statistics/rx_bytes' '/statistics/tx_bytes'; do
  grep -Fq -- "$text" <<<"$throughput_process" || {
    printf 'Wireless throughput Process contract missing: %s\n' "$text" >&2
    exit 1
  }
done
if grep -Eiq 'password|nmcli|connect|disconnect|scanner|wifiEnabled' <<<"$throughput_process"; then
  printf 'Wireless throughput Process must only pass passive /sys arguments\n' >&2
  exit 1
fi
printf 'ok - uptime uses one-shot profile metadata and throughput passively reads /sys\n'

for file_kind in popup settings; do
  if [[ "$file_kind" == popup ]]; then
    ui_file="$popup"
  else
    ui_file="$settings"
  fi
  grep -Fq 'model: WirelessManager.networks' "$ui_file"
  for declaration in \
    'required property string networkKey' \
    'required property string ssid' \
    'required property int signal' \
    'required property bool secured' \
    'required property bool known' \
    'required property bool connected' \
    'required property bool stateChanging'; do
    grep -Fq -- "$declaration" "$ui_file" || {
      printf 'Wireless %s primitive delegate contract missing: %s\n' "$file_kind" "$declaration" >&2
      exit 1
    }
  done
  if grep -Fq 'modelData.' "$ui_file"; then
    printf 'Wireless %s delegates must consume primitive ListModel roles\n' "$file_kind" >&2
    exit 1
  fi
  for state in actionMessage actionKey failureMessage failureKey busy; do
    grep -Fq "WirelessManager.$state" "$ui_file" || {
      printf 'Wireless %s does not expose %s state\n' "$file_kind" "$state" >&2
      exit 1
    }
  done
done
assert_popup_contains 'WirelessManager.getConnectionDurationLong()'
printf 'ok - popup and settings consume primitive roles and expose action and error states\n'

assert_popup_contains 'WirelessManager.startScanning()'
assert_popup_contains 'WirelessManager.stopScanning()'
assert_popup_contains 'FocusListItem {'
assert_popup_contains 'FocusIconButton {'
if [[ $(grep -Fc 'WirelessManager.forget(' "$popup") -lt 2 ]]; then
  printf 'Wireless popup must provide distinct focusable forget controls for known networks\n' >&2
  exit 1
fi
assert_popup_contains 'WirelessManager.connectWithPsk(networkDelegate.networkKey, password)'
if grep -Fq 'contentLeftMargin: 0' "$popup"; then
  printf 'Wireless popup network icons must keep the standard content inset\n' >&2
  exit 1
fi
printf 'ok - popup owns continuous scanning and has inset, keyboard-focusable network actions\n'

assert_settings_contains 'onClicked: WirelessManager.requestScan()'
if grep -Fq 'WirelessManager.startScanning()' "$settings"; then
  printf 'Wireless settings scanning must remain bounded\n' >&2
  exit 1
fi
if [[ $(grep -Fc 'FocusLink {' "$settings") -lt 3 ]] \
    || [[ $(grep -Fc 'text: "Forget"' "$settings") -lt 2 ]] \
    || [[ $(grep -Fc 'WirelessManager.forget(' "$settings") -lt 2 ]]; then
  printf 'Wireless settings forget actions must be distinct keyboard-focusable controls\n' >&2
  exit 1
fi
assert_settings_contains 'WirelessManager.connectWithPsk(networkDelegate.networkKey, password)'
printf 'ok - settings uses bounded scanning and separate keyboard-focusable network actions\n'

[[ -f "$wireless_doc" ]] || {
  printf 'Wireless documentation is missing: docs/wiki/wireless.md\n' >&2
  exit 1
}
for text in 'Quickshell.Networking' 'primitive' 'device name and SSID' 'continuous scan' 'bounded' 'connectWithPsk' '30-second timeout' 'one-shot metadata lookup' '/sys/class/net/' 'bar-tooltip uptime'; do
  assert_doc_contains "$text"
done
grep -Fq -- '[Wireless](wireless.md)' "$wiki_index" || {
  printf 'Wiki index must link docs/wiki/wireless.md\n' >&2
  exit 1
}
printf 'ok - wireless native behavior and scope are documented and linked from the wiki index\n'
