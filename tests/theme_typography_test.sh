#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
theme="$repo_root/core/Theme.qml"
tooltip_text="$repo_root/core/components/TooltipText.qml"

# Defaults and public tokens.
grep -Fq 'readonly property string _defaultFontFamily: "sans-serif"' "$theme"
grep -Fq 'readonly property real _defaultFontSizeBody: 14' "$theme"
grep -Fq 'property string fontFamily: _defaultFontFamily' "$theme"
grep -Fq 'property real fontSizeBody: _defaultFontSizeBody' "$theme"

# Every parsed theme either applies valid overrides or resets to defaults.
grep -Fq 'fontFamily = typeof t.fontFamily === "string" && t.fontFamily.trim() !== "" ? t.fontFamily : _defaultFontFamily' "$theme"
grep -Fq 'fontSizeBody = typeof t.fontSizeBody === "number" && isFinite(t.fontSizeBody) && t.fontSizeBody > 0 ? t.fontSizeBody : _defaultFontSizeBody' "$theme"

grep -Fq 'color: Theme.textPrimary' "$tooltip_text"
grep -Fq 'font.family: Theme.fontFamily' "$tooltip_text"
grep -Fq 'font.pixelSize: Theme.fontSizeBody' "$tooltip_text"
if grep -Fq 'font.pixelSize: 14' "$tooltip_text"; then
  exit 1
fi

grep -Fxq 'TooltipText 1.0 TooltipText.qml' "$repo_root/core/components/qmldir"

echo 'theme typography source contract tests passed'
