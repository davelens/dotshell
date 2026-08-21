#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
screen_manager="$repo_root/core/ScreenManager.qml"
compositor="$repo_root/core/Compositor.qml"
display_manager="$repo_root/modules/display/Manager.qml"
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

# The focused workspace can be moved to either compositor's named output.
grep -Fq 'Compositor.moveFocusedWorkspaceToOutput(modelData.name)' "$settings"
grep -Fq '["swaymsg", "move", "workspace", "to", "output", name]' "$compositor"
grep -Fq '["niri", "msg", "action", "move-workspace-to-monitor", name]' "$compositor"

echo 'display settings source contract tests passed'
