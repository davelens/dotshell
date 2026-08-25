#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
manager="$repo_root/modules/bluetooth/Manager.qml"
settings="$repo_root/modules/bluetooth/Settings.qml"

# Connected devices can be renamed inline and submitted by Save or Enter.
grep -Fq 'text: "Rename"' "$settings"
grep -Fq 'text: "Save"' "$settings"
test "$(grep -Fc 'FocusButton {' "$settings")" -eq 3
grep -Fq 'text: modelData.name' "$settings"
grep -Fq 'onEditingFinished: connectedDevice.saveName()' "$settings"
grep -Fq 'BluetoothManager.renameDevice(modelData.address, renameInput.text)' "$settings"

# Quickshell's writable device name is the local BlueZ alias and remains the
# first display-name choice when native device state updates.
grep -Fq 'name: device.name || device.deviceName || device.address' "$manager"
grep -Fq 'device.name = name' "$manager"
grep -Fq 'connectError = "Could not rename this device."' "$manager"

echo 'bluetooth rename source contract tests passed'
