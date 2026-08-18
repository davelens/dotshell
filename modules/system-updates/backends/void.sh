#!/usr/bin/env bash

# Updates backend interface for Void Linux. Commands follow the Void Handbook:
# xbps-install -Su performs a full update; -M + -n previews against fresh
# in-memory repository indexes without changing package-manager state.

describe() {
  printf '%s\n' '{"supported":true,"name":"Void Linux","repoLabel":"XBPS","communityLabel":"","hasCommunity":false,"systemDescription":"Full system upgrade (XBPS)","runningDescription":"Running xbps-install -Su"}'
}

check_updates() {
  local pkgver action _arch _repository _installed_size _download_size
  local name current_pkgver current_version new_version

  while read -r pkgver action _arch _repository _installed_size _download_size; do
    [[ "$action" == "update" ]] || continue
    name="$(xbps-uhelper getpkgname "$pkgver")"
    new_version="$(xbps-uhelper getpkgversion "$pkgver")"
    current_pkgver="$(xbps-query -p pkgver "$name")"
    current_version="$(xbps-uhelper getpkgversion "$current_pkgver")"
    printf 'repo\t%s\t%s\t%s\n' "$name" "$current_version" "$new_version"
  done < <(xbps-install -Mun 2>/dev/null)
}

update_package() {
  local source="$1" name="$2"
  if [[ "$source" != "repo" ]]; then
    echo "error: unknown Void package source '$source'" >&2
    return 2
  fi
  pkexec /usr/bin/xbps-install -Suy "$name"
}

update_source() {
  local source="$1"
  shift
  if [[ "$source" != "repo" ]]; then
    echo "error: unknown Void package source '$source'" >&2
    return 2
  fi
  pkexec /usr/bin/xbps-install -Suy "$@"
}

system_update() {
  local include_flatpak="${1:-0}"

  # XBPS must update itself in a separate transaction when an update exists.
  # Run both transactions under one polkit authorization prompt.
  pkexec /bin/sh -c \
    '/usr/bin/xbps-install -Suy xbps && /usr/bin/xbps-install -uy'
  if [[ "$include_flatpak" == "1" ]]; then
    flatpak update -y
  fi
}
