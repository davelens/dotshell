#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dropdown="$repo_root/core/components/Dropdown.qml"

grep -Fq '  function selectItem(item) {
    itemSelected(item)
    expanded = false
    highlightIndex = -1
    toggled(false)
  }' "$dropdown"
grep -Fq 'dropdown.selectItem(dropdown.items[dropdown.highlightIndex])' "$dropdown"
[[ "$(grep -cF 'onClicked: dropdown.selectItem(modelData)' "$dropdown")" -eq 2 ]]
[[ "$(grep -cF 'selectItem(' "$dropdown")" -eq 4 ]]

echo 'dropdown source contract tests passed'
