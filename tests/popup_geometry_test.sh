#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
popup_base="$repo_root/core/components/PopupBase.qml"

grep -Fq 'x: Math.max(0, Math.min(computedX, popupBase.width - width))' "$popup_base"
grep -Fq 'popupBase.width - Math.min(24, popupBase.width / 2)))' "$popup_base"
grep -Fq 'popupBase.height - y - 24))' "$popup_base"
grep -Fq 'default property alias content: contentColumn.data' "$popup_base"
grep -Fq 'readonly property alias contentColumn: contentColumn' "$popup_base"
[[ "$(grep -c '    Flickable {' "$popup_base")" -eq 1 ]]
grep -Fq 'contentHeight: contentColumn.implicitHeight' "$popup_base"
grep -Fq 'clip: true' "$popup_base"
grep -Fq 'boundsBehavior: Flickable.StopAtBounds' "$popup_base"

echo 'popup geometry source contract tests passed'
