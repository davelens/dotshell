#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
popup_manager="$repo_root/core/PopupManager.qml"
bar_button="$repo_root/core/components/BarButton.qml"
handler="$(sed -n '/  IpcHandler {/,/^  }$/p' "$popup_manager")"

validation="ModuleRegistry.getPopupModuleIds().indexOf(name) === -1"
error_return="return \"error: unknown popup '\" + name + \"'\""
grep -Fq "$validation" <<<"$handler"
grep -Fq "$error_return" <<<"$handler"

validation_line="$(grep -nF "$validation" <<<"$handler" | cut -d: -f1)"
first_effect_line="$(grep -nE 'OverlayManager\.close|popupManager\.(close\(|activePopup =|anchorRight =|anchoredToButton =)' <<<"$handler" | head -n1 | cut -d: -f1)"
((validation_line < first_effect_line))

# IPC toggles reuse a visible bar button on the focused screen, so keyboard
# opens retain the same anchor and stem as clicks. Missing buttons stay stemless.
grep -Fq 'popupManager.registerButton(popupId, button)' "$bar_button"
grep -Fq 'button.screen !== screen || !button.visible' "$popup_manager"
grep -Fq 'button.showInBar !== undefined && !button.showInBar' "$popup_manager"
grep -Fq 'popupManager.getButtonAnchor(name, screen)' <<<"$handler"
grep -Fq 'anchor !== null ? anchor : screen.width - 20' <<<"$handler"
grep -Fq 'popupManager.anchoredToButton = anchor !== null' <<<"$handler"

echo 'popup IPC source contract tests passed'
