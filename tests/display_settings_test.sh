#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
screen_manager="$repo_root/core/ScreenManager.qml"
compositor="$repo_root/core/Compositor.qml"
display_manager="$repo_root/modules/display/Manager.qml"
popup="$repo_root/modules/display/Popup.qml"
settings="$repo_root/modules/display/Settings.qml"

# Incomplete ShellScreen metadata must not collapse multiple outputs into one id.
grep -Fq 'model === "Unknown" || !serial || serial === "Unknown"' "$screen_manager"
grep -Fq 'return screen.name' "$screen_manager"

# Sway's richer output data labels the screen and exposes workspace placement.
grep -Fq 'workspace: sway.current_workspace || ""' "$display_manager"
grep -Fq 'ScreenManager.friendlyName(screen, output ? output.model : "")' "$settings"
grep -Fq 'modelData.workspace ? "Workspace " + modelData.workspace : "No active workspace"' "$settings"

# Monitor placement applies immediately and serializes compositor commands.
grep -Fq 'settingsRoot.applyLayout()' "$settings"
grep -Fq 'property var pendingPositions: []' "$settings"
grep -Fq 'Compositor.applyPosition(position.name, position.x, position.y)' "$settings"
if grep -Fq 'pendingApplyCount' "$settings" || grep -Fq 'text: "Apply"' "$settings" \
    || grep -Fq 'text: "Reset"' "$settings"; then
  echo 'display positions must apply immediately and sequentially without extra controls' >&2
  exit 1
fi

# Popup header matches the other connectivity popups without monitor identifiers.
grep -Fq 'font.pixelSize: Theme.scaledFontSize(16)' "$popup"
grep -Fq 'color: Theme.textPrimary' "$popup"
grep -Fq 'color: Theme.bgCardHover' "$popup"
test "$(grep -Fc 'text: "Displays"' "$popup")" -eq 1
if grep -Fq 'DisplayManager.selectedOutput.model' "$popup" \
    || grep -Fq 'text: DisplayManager.selectedOutput ? DisplayManager.selectedOutput.name : ""' "$popup"; then
  echo 'display popup header must not show a monitor identifier' >&2
  exit 1
fi

# Global text size follows the selected monitor's render scale controls.
render_scale_line="$(grep -nF 'title: "Render scale"' "$popup" | cut -d: -f1)"
text_size_line="$(grep -nF 'title: "Text size (global)"' "$popup" | cut -d: -f1)"
test "$render_scale_line" -lt "$text_size_line"

# A collapsed single-display list must not leave an extra separator behind.
grep -Fq 'visible: DisplayManager.brightnessAvailable && DisplayManager.outputs.length > 1' "$popup"

# Popup output selection only targets its controls; primary display changes in settings.
grep -Fq 'ScreenManager.setPrimary(modelData)' "$settings"
if grep -Fq 'ScreenManager.setPrimary' "$display_manager"; then
  echo 'display popup selection must not move the status bar' >&2
  exit 1
fi

# The focused workspace can be moved to either compositor's named output.
grep -Fq 'Compositor.moveFocusedWorkspaceToOutput(modelData.name)' "$settings"
grep -Fq '["swaymsg", "move", "workspace", "to", "output", name]' "$compositor"
grep -Fq '["niri", "msg", "action", "move-workspace-to-monitor", name]' "$compositor"

echo 'display settings source contract tests passed'
