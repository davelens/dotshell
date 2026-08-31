#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Every bar declaration names a valid section and a numeric order
for f in "$repo_root"/modules/*/module.json; do
  jq -e '.bar == null or
    ((.bar.section | IN("left", "center", "right")) and (.bar.order | type == "number"))' \
    "$f" >/dev/null || { echo "error: invalid bar declaration in $f" >&2; exit 1; }
done

# Non-core modules ship no default bar placement
for id in active-collab ai-agents-monitor wallpaper system-load; do
  jq -e '.bar == null' "$repo_root/modules/$id/module.json" >/dev/null ||
    { echo "error: $id must not declare bar defaults" >&2; exit 1; }
done

# The manifest-assembled default layout matches the expected core layout
layout="$(jq -s '[.[] | select(.bar) | {id, section: .bar.section, order: .bar.order}]
  | sort_by(.order) | group_by(.section)
  | map({(.[0].section): map(.id)}) | add' "$repo_root"/modules/*/module.json)"
[[ "$(jq -r '.left | join(" ")' <<<"$layout")" == "power idle-inhibitor workspaces" ]]
[[ "$(jq -r '.center | join(" ")' <<<"$layout")" == "media" ]]
[[ "$(jq -r '.right | join(" ")' <<<"$layout")" == \
  "screen-recording wireless bluetooth display volume battery clock system-updates notifications" ]]

echo 'statusbar defaults tests passed'
