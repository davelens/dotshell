#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bluetooth="$repo_root/modules/bluetooth/Popup.qml"
wireless="$repo_root/modules/wireless/Popup.qml"
list_item="$repo_root/core/components/FocusListItem.qml"

# List labels reserve their right icon's space and reveal the full text only
# when the rendered label is actually truncated.
grep -Fq 'id: itemText' "$list_item"
grep -Fq 'anchors.right: rightIconText.left' "$list_item"
grep -Fq 'elide: Text.ElideRight' "$list_item"
grep -Fq 'visible: itemText.truncated && mouseArea.containsMouse' "$list_item"

# Refresh glyphs share the 12px text inset used by row actions/icons. The
# FocusIconButton contributes 4px of its own padding, leaving an 8px margin.
grep -Fq 'id: availableDevicesRefresh' "$bluetooth"
grep -Fq 'anchors.rightMargin: 8' "$bluetooth"
grep -Fq 'id: availableNetworksRefresh' "$wireless"
grep -Fq 'anchors.rightMargin: 8' "$wireless"

echo 'connectivity popup layout source contract tests passed'
