#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
popup_manager="$repo_root/core/PopupManager.qml"

if grep -qE 'activePopupScreen|storedAnchors' "$popup_manager"; then
  exit 1
fi
grep -Fq 'function toggle(name: string, buttonRight: real): void' "$popup_manager"
grep -Fq 'popupManager.toggle(button.popupId, mapped.x)' "$repo_root/core/components/BarButton.qml"
grep -Fq 'PopupManager.toggle(moduleId, anchorRight)' "$repo_root/shell.qml"

echo 'popup manager cleanup tests passed'
