#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
popup_manager="$repo_root/core/PopupManager.qml"
handler="$(sed -n '/  IpcHandler {/,/^  }$/p' "$popup_manager")"

validation="ModuleRegistry.getPopupModuleIds().indexOf(name) === -1"
error_return="return \"error: unknown popup '\" + name + \"'\""
grep -Fq "$validation" <<<"$handler"
grep -Fq "$error_return" <<<"$handler"

validation_line="$(grep -nF "$validation" <<<"$handler" | cut -d: -f1)"
first_effect_line="$(grep -nE 'OverlayManager\.close|popupManager\.(close\(|activePopup =|anchorRight =|anchoredToButton =)' <<<"$handler" | head -n1 | cut -d: -f1)"
((validation_line < first_effect_line))

echo 'popup IPC source contract tests passed'
