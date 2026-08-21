#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
slider="$repo_root/core/components/FocusSlider.qml"

# User interaction must not replace the caller's reactive value binding.
grep -Fq 'property alias value: control.value' "$slider"
if grep -Fq 'onValueChanged: control.value = value' "$slider" \
    || grep -Fq 'onValueChanged: slider.value = value' "$slider"; then
  echo 'FocusSlider must not break its external value binding' >&2
  exit 1
fi

echo 'focus slider source contract tests passed'
