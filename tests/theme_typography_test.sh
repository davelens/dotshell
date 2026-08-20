#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
theme="$repo_root/core/Theme.qml"
tooltip_text="$repo_root/core/components/TooltipText.qml"
body_text="$repo_root/core/components/BodyText.qml"
focus_button="$repo_root/core/components/FocusButton.qml"
focus_text_input="$repo_root/core/components/FocusTextInput.qml"

# Defaults and public tokens.
grep -Fq 'readonly property string _defaultFontFamily: "Hack Nerd Font"' "$theme"
grep -Fq 'readonly property real _defaultFontSizeBody: 14' "$theme"
grep -Fq 'property string fontFamily: _defaultFontFamily' "$theme"
grep -Fq 'property real fontSizeBody: _defaultFontSizeBody' "$theme"
grep -Fq 'property real fontScale: 1.0' "$theme"
grep -Fq 'function scaledFontSize(pixelSize) {' "$theme"
grep -Fq 'return pixelSize * theme.fontScale' "$theme"

# Every parsed theme either applies valid overrides or resets to defaults.
grep -Fq 'fontFamily = typeof t.fontFamily === "string" && t.fontFamily.trim() !== "" ? t.fontFamily : _defaultFontFamily' "$theme"
grep -Fq 'fontSizeBody = typeof t.fontSizeBody === "number" && isFinite(t.fontSizeBody) && t.fontSizeBody > 0 ? t.fontSizeBody : _defaultFontSizeBody' "$theme"

grep -Fq 'color: Theme.textPrimary' "$tooltip_text"
grep -Fq 'font.family: Theme.fontFamily' "$tooltip_text"
grep -Fq 'font.pixelSize: Theme.scaledFontSize(Theme.fontSizeBody)' "$tooltip_text"

# Every pixel-size binding routes through the live scaling seam.
unscaled_font_sizes="$(
  grep -RIn --include='*.qml' -E 'font\.pixelSize[[:space:]]*:' \
    "$repo_root/core" "$repo_root/settings" "$repo_root/statusbar" "$repo_root/modules" \
    | grep -vE 'font\.pixelSize[[:space:]]*:[[:space:]]*Theme\.scaledFontSize\(' \
    || true
)"
if [[ -n "$unscaled_font_sizes" ]]; then
  printf '%s\n' "$unscaled_font_sizes"
  exit 1
fi

# Shared text renderers inherit the global family.
grep -Fq 'font.family: Theme.fontFamily' "$body_text"
grep -A5 -F 'text: button.text' "$focus_button" | grep -Fq 'font.family: Theme.fontFamily'
grep -A5 -F 'id: textField' "$focus_text_input" | grep -Fq 'font.family: Theme.fontFamily'

grep -Fxq 'TooltipText 1.0 TooltipText.qml' "$repo_root/core/components/qmldir"

echo 'theme typography source contract tests passed'
