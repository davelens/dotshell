#!/usr/bin/env bash
set -e

DOTSHELL_REPO_HOME="$(cd "$(dirname "$(dirname "${BASH_SOURCE[0]}")")" && pwd)"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

# Platform adapters share setup and uninstall behavior.
# shellcheck source=/dev/null
. "$DOTSHELL_REPO_HOME/setup/lib/platform.sh"
platform_loaded=false
if load_platform "$DOTSHELL_REPO_HOME/setup"; then
  platform_loaded=true
fi

echo "This will remove:"
if [[ "$platform_loaded" == true ]]; then
  echo "  - $(platform_service_description)"
else
  echo "  - dotshell user service (manual cleanup may be required)"
fi
echo "  - $XDG_CONFIG_HOME/dotshell (symlink)"
echo "  - $XDG_DATA_HOME/dotshell (profile data)"
echo "  - $XDG_DATA_HOME/applications/dotshell-settings.desktop"
echo "  - $XDG_RUNTIME_DIR/quickshell (Quickshell runtime logs)"
echo "  - Quickshell runtime package"
echo
read -rp "Continue? [y/N] " confirm
[[ "$confirm" =~ ^[Yy]$ ]] || {
  echo "Aborted."
  exit 0
}

if [[ "$platform_loaded" == true ]]; then
  platform_stop_service
fi

if [[ -L "$XDG_CONFIG_HOME/dotshell" ]]; then
  echo "==> Removing config symlink: $XDG_CONFIG_HOME/dotshell"
  rm "$XDG_CONFIG_HOME/dotshell"
elif [[ -d "$XDG_CONFIG_HOME/dotshell" ]]; then
  echo "==> Removing config directory: $XDG_CONFIG_HOME/dotshell"
  rm -rf "$XDG_CONFIG_HOME/dotshell"
fi

if [[ -d "$XDG_DATA_HOME/dotshell" ]]; then
  echo "==> Removing data directory: $XDG_DATA_HOME/dotshell"
  rm -rf "$XDG_DATA_HOME/dotshell"
fi

for desktop_entry in dotshell-settings.desktop quickshell-settings.desktop; do
  if [[ -f "$XDG_DATA_HOME/applications/$desktop_entry" ]]; then
    echo "==> Removing desktop entry: $desktop_entry"
    rm "$XDG_DATA_HOME/applications/$desktop_entry"
  fi
done

if [[ -d "$XDG_RUNTIME_DIR/quickshell" ]]; then
  echo "==> Removing runtime directory: $XDG_RUNTIME_DIR/quickshell"
  rm -rf "$XDG_RUNTIME_DIR/quickshell"
fi

if [[ "$platform_loaded" == true ]]; then
  platform_uninstall_package
else
  echo "==> Unknown distribution; leaving the Quickshell runtime package installed"
fi

echo "==> Uninstall complete."
echo
echo "Note: The dotshell repo itself was not removed."
echo "  To delete it: rm -rf ~/Repositories/davelens/dotshell"
