#!/usr/bin/env bash

# Updates backend interface for Arch Linux.

describe() {
  printf '%s\n' '{"supported":true,"name":"Arch Linux","repoLabel":"Official","communityLabel":"AUR","hasCommunity":true,"systemDescription":"Full system upgrade (pacman + AUR)","runningDescription":"Running paru -Syu"}'
}

check_updates() {
  if command -v checkupdates >/dev/null 2>&1; then
    checkupdates 2>/dev/null \
      | grep -Fw -f <(pacman -Qqe) \
      | awk '{ print "repo\t" $1 "\t" $2 "\t" $4 }' \
      || true
  fi

  if command -v paru >/dev/null 2>&1; then
    paru -Qua 2>/dev/null \
      | grep -Fw -f <(pacman -Qqem) \
      | awk '{ print "community\t" $1 "\t" $2 "\t" $4 }' \
      || true
  fi
}

update_package() {
  local source="$1" name="$2"
  case "$source" in
    repo)
      sudo pacman -Sy
      sudo pacman -S --needed --noconfirm "$name"
      ;;
    community)
      paru -S --needed --noconfirm --skipreview --sudoloop "$name"
      ;;
    *)
      echo "error: unknown Arch package source '$source'" >&2
      return 2
      ;;
  esac
}

update_source() {
  local source="$1"
  shift
  case "$source" in
    repo)
      sudo pacman -Sy
      sudo pacman -S --needed --noconfirm "$@"
      ;;
    community)
      paru -S --needed --noconfirm --skipreview --sudoloop "$@"
      ;;
    *)
      echo "error: unknown Arch package source '$source'" >&2
      return 2
      ;;
  esac
}

system_update() {
  local include_flatpak="${1:-0}"
  paru -Syu --noconfirm --skipreview --sudoloop
  if [[ "$include_flatpak" == "1" ]]; then
    flatpak update -y
  fi
}
