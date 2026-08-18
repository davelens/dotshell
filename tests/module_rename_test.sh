#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
sandbox="$(mktemp -d)"
trap 'rm -rf "$sandbox"' EXIT
mkdir -p "$sandbox/profile"

printf '%s\n' '{"includeFlatpak":true}' >"$sandbox/profile/updates.json"
printf '%s\n' '{"processName":"recorder"}' >"$sandbox/recording-general.json"
bash "$repo_root/core/migrate-module-state" "$sandbox/profile" "" \
  updates system-updates
bash "$repo_root/core/migrate-module-state" "$sandbox" -general \
  recording screen-recording
[[ ! -e "$sandbox/profile/updates.json" ]]
[[ "$(jq -r .includeFlatpak "$sandbox/profile/system-updates.json")" == true ]]
[[ ! -e "$sandbox/recording-general.json" ]]
[[ "$(jq -r .processName "$sandbox/screen-recording-general.json")" == recorder ]]

printf '%s\n' old >"$sandbox/profile/updates.json"
printf '%s\n' new >"$sandbox/profile/system-updates.json"
bash "$repo_root/core/migrate-module-state" "$sandbox/profile" "" \
  updates system-updates
[[ "$(<"$sandbox/profile/updates.json")" == old ]]
[[ "$(<"$sandbox/profile/system-updates.json")" == new ]]

jq -e '.formerlyKnownAs == ["updates"]' \
  "$repo_root/modules/system-updates/module.json" >/dev/null
jq -e '.formerlyKnownAs == ["recording"]' \
  "$repo_root/modules/screen-recording/module.json" >/dev/null

echo 'module rename migration tests passed'
