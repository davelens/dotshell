#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
screen_manager="$repo_root/core/ScreenManager.qml"
compositor="$repo_root/core/Compositor.qml"
overlay_manager="$repo_root/core/OverlayManager.qml"
popup_manager="$repo_root/core/PopupManager.qml"
module_popup="$repo_root/core/components/ModulePopup.qml"
bar_button="$repo_root/core/components/BarButton.qml"

# Keyboard/IPC opens resolve the compositor's focused output, with primary fallback.
grep -Fq 'import Quickshell.I3' "$screen_manager"
grep -Fq 'readonly property var focusedScreen:' "$screen_manager"
grep -Fq 'I3.focusedMonitor' "$screen_manager"
grep -Fq 'Compositor.focusedOutputName' "$screen_manager"
grep -Fq 'command: ["niri", "msg", "-j", "focused-output"]' "$compositor"
grep -Fq 'command: ["niri", "msg", "-j", "event-stream"]' "$compositor"
grep -Fq 'line.indexOf("WorkspacesChanged")' "$compositor"
grep -Fq 'line.indexOf("WorkspaceActivated")' "$compositor"
grep -Fq 'screen || ScreenManager.focusedScreen || ScreenManager.primaryScreen' "$overlay_manager"
grep -Fq 'ScreenManager.focusedScreen || ScreenManager.primaryScreen' "$popup_manager"

# Placement is snapshotted at open time; bar clicks retain their source screen.
grep -Fq 'property var targetScreen: null' "$overlay_manager"
grep -Fq 'property var targetScreen: null' "$popup_manager"
grep -Fq 'PopupManager.targetScreen' "$module_popup"
grep -Fq 'button.popupManager.toggle(button.popupId, mapped.x, button.screen)' "$bar_button"
grep -Fq 'PopupManager.toggle(moduleId, anchorRight, modelData)' "$repo_root/shell.qml"

for panel in \
  "$repo_root/settings/Panel.qml" \
  "$repo_root/modules/power/Overlay.qml" \
  "$repo_root/modules/wallpaper/Panel.qml" \
  "$repo_root/modules/screen-recording/Panel.qml"; do
  grep -Fq 'OverlayManager.targetScreen' "$panel"
done

grep -Fq 'root.panelScreen = OverlayManager.targetScreen' "$repo_root/modules/notifications/Panel.qml"
grep -Fq 'signal popupShown()' "$repo_root/modules/notifications/Manager.qml"
grep -Fq 'root.popupScreen = ScreenManager.focusedScreen || ScreenManager.primaryScreen' \
  "$repo_root/modules/notifications/Popups.qml"
grep -Fq '? [root.popupScreen] : []' "$repo_root/modules/notifications/Popups.qml"

echo 'focused screen source contract tests passed'
