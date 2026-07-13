#!/usr/bin/env bash

load_platform() {
  local setup_dir="$1"
  local adapter
  local os_release_file="${DOTSHELL_OS_RELEASE:-/etc/os-release}"

  if [[ ! -r "$os_release_file" ]]; then
    echo "error: cannot detect the Linux distribution ($os_release_file is missing)" >&2
    return 1
  fi

  # shellcheck source=/dev/null
  . "$os_release_file"
  DISTRO="${ID:-unknown}"
  adapter="$setup_dir/platforms/$DISTRO.sh"

  if [[ ! -r "$adapter" ]]; then
    local supported
    supported="$(find "$setup_dir/platforms" -maxdepth 1 -type f -name '*.sh' -printf '%f\n' \
      | sed 's/\.sh$//' | sort | paste -sd ', ' -)"
    echo "error: unsupported distribution '$DISTRO' (supported: $supported)" >&2
    return 1
  fi

  # Each platform adapter implements package and service operations for both
  # setup and uninstall. Adding a distribution does not change either caller.
  # shellcheck source=/dev/null
  . "$adapter"

  local function_name
  for function_name in \
    platform_service_description \
    platform_install_packages \
    platform_setup_service \
    platform_stop_service \
    platform_uninstall_package; do
    if ! declare -F "$function_name" >/dev/null; then
      echo "error: platform adapter '$adapter' does not implement $function_name" >&2
      return 1
    fi
  done
}
