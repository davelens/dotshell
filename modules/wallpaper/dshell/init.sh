#!/usr/bin/env bash

# shellcheck disable=SC2154,SC2317,SC2329
dshell_wallpaper_set() {
  local path="$1"
  [[ -f "$path" ]] || die "wallpaper file not found: $path"
  ipc wallpaper set "$path"
}

dshell_wallpaper_restore() {
  local fallback="${1:-}"
  local profile_dir wallpaper=""
  profile_dir="$(json_get "$GENERAL_JSON" '.activeProfile')"
  if [[ -n "$profile_dir" ]]; then
    wallpaper="$(json_get "$DATA_DIR/${profile_dir}/wallpaper.json" '.currentWallpaper')"
  fi

  if [[ -z "$wallpaper" || ! -f "$wallpaper" ]]; then
    if [[ -n "$fallback" && -f "$fallback" ]]; then
      wallpaper="$fallback"
    else
      echo "No saved wallpaper found" >&2
      return 1
    fi
  fi

  if [[ -n "${SWAYSOCK:-}" || -n "${I3SOCK:-}" ]]; then
    swaymsg output '*' bg "$wallpaper" fill
  else
    pkill -x swaybg 2>/dev/null || true
    sleep 0.1
    swaybg -o '*' -i "$wallpaper" -m fill &
    disown
  fi
}

dshell_register_group "Wallpaper browser and setter"
dshell_register_command "browser toggle" "ipc overlay toggle wallpaper" "" \
  "Toggle the wallpaper browser"
dshell_register_command "browser open" "ipc overlay open wallpaper" "" \
  "Open the wallpaper browser"
dshell_register_command "browser close" "ipc overlay close wallpaper" "" \
  "Close the wallpaper browser"
dshell_register_command "set" "fn dshell_wallpaper_set" "<path:file>" \
  "Set a wallpaper by file path"
dshell_register_command "restore" "fn dshell_wallpaper_restore" "[fallback:file]" \
  "Restore saved wallpaper (optional fallback)"
