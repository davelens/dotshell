#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

test_scripts=(tests/*_test.sh)

bash -n setup/init.sh setup/uninstall.sh setup/lib/platform.sh setup/platforms/*.sh \
  bin/dshell bin/generate-gtk-css core/migrate-module-state modules/*/dshell/init.sh \
  modules/ai-agents-monitor/bin/pi-discover \
  modules/ai-agents-monitor/bin/remote-stream modules/notifications/bin/remote-stream \
  modules/display/bin/display-brightness modules/display/bin/display-text-size \
  modules/bluetooth/bin/bluetooth-device \
  tests/run.sh "${test_scripts[@]}"
bash -n modules/volume/bin/volume-set-default

if ! command -v jq >/dev/null 2>&1; then
  echo "error: jq is required to validate JSON files" >&2
  exit 1
fi

while IFS= read -r -d '' json_file; do
  jq empty "$json_file"
done < <(find core modules statusbar themes -name '*.json' -type f -print0)

if command -v shellcheck >/dev/null 2>&1; then
  shellcheck setup/init.sh setup/uninstall.sh setup/dotshell.run setup/lib/platform.sh \
    setup/platforms/*.sh core/migrate-module-state modules/*/dshell/init.sh \
    modules/ai-agents-monitor/bin/pi-discover \
    modules/ai-agents-monitor/bin/remote-stream modules/notifications/bin/remote-stream \
    modules/display/bin/display-brightness modules/display/bin/display-text-size \
    modules/bluetooth/bin/bluetooth-device \
    tests/run.sh "${test_scripts[@]}"
  shellcheck modules/volume/bin/volume-set-default
fi

bash tests/dshell_test.sh
bash tests/module_rename_test.sh
bash tests/statusbar_defaults_test.sh
bash tests/pi_discover_test.sh
bash tests/pi_agent_state_test.sh
bash tests/remote_stream_test.sh
bash tests/notification_remote_stream_test.sh
bash tests/popup_manager_cleanup_test.sh
bash tests/popup_ipc_test.sh
bash tests/popup_geometry_test.sh
bash tests/dropdown_test.sh
bash tests/focused_screen_test.sh
bash tests/focus_slider_test.sh
bash tests/display_brightness_test.sh
bash tests/bluetooth_device_test.sh
bash tests/bluetooth_test.sh
bash tests/bluetooth_rename_test.sh
bash tests/connectivity_popup_layout_test.sh
bash tests/volume_test.sh
bash tests/wireless_test.sh
bash tests/display_clamshell_test.sh
bash tests/display_settings_test.sh
bash tests/display_text_size_test.sh
bash tests/theme_typography_test.sh
bash tests/theme_font_coverage_test.sh
bash tests/setup_test.sh
