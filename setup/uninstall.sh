#!/usr/bin/env bash
set -e

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

echo "This will remove:"
echo "  - Quickshell systemd user service"
echo "  - $XDG_CONFIG_HOME/dotshell (symlink)"
echo "  - $XDG_DATA_HOME/dotshell (profile data)"
echo "  - $XDG_DATA_HOME/applications/quickshell-settings.desktop"
echo "  - $XDG_RUNTIME_DIR/quickshell (runtime logs)"
echo "  - quickshell-git package (or quickshell)"
echo ""
read -rp "Continue? [y/N] " confirm
[[ "$confirm" =~ ^[Yy]$ ]] || {
  echo "Aborted."
  exit 0
}

# Stop and disable the systemd service
echo "==> Stopping quickshell service..."
systemctl --user stop quickshell.service 2>/dev/null || true
systemctl --user disable quickshell.service 2>/dev/null || true
systemctl --user daemon-reload

# Remove config symlink
if [[ -L "$XDG_CONFIG_HOME/dotshell" ]]; then
  echo "==> Removing config symlink: $XDG_CONFIG_HOME/dotshell"
  rm "$XDG_CONFIG_HOME/dotshell"
elif [[ -d "$XDG_CONFIG_HOME/dotshell" ]]; then
  echo "==> Removing config directory: $XDG_CONFIG_HOME/dotshell"
  rm -rf "$XDG_CONFIG_HOME/dotshell"
fi

# Remove profile/state data
if [[ -d "$XDG_DATA_HOME/dotshell" ]]; then
  echo "==> Removing data directory: $XDG_DATA_HOME/dotshell"
  rm -rf "$XDG_DATA_HOME/dotshell"
fi

# Remove desktop entry
if [[ -f "$XDG_DATA_HOME/applications/quickshell-settings.desktop" ]]; then
  echo "==> Removing desktop entry"
  rm "$XDG_DATA_HOME/applications/quickshell-settings.desktop"
fi

# Remove runtime logs
if [[ -d "$XDG_RUNTIME_DIR/quickshell" ]]; then
  echo "==> Removing runtime directory: $XDG_RUNTIME_DIR/quickshell"
  rm -rf "$XDG_RUNTIME_DIR/quickshell"
fi

# Uninstall quickshell package
if pacman -Qi quickshell-git &>/dev/null; then
  echo "==> Uninstalling quickshell-git..."
  sudo pacman -Rns --noconfirm quickshell-git
elif pacman -Qi quickshell &>/dev/null; then
  echo "==> Uninstalling quickshell..."
  sudo pacman -Rns --noconfirm quickshell
else
  echo "==> quickshell package not found, skipping"
fi

echo "==> Uninstall complete."
echo ""
echo "Note: The dotshell repo itself was not removed."
echo "  To delete it: rm -rf ~/Repositories/davelens/dotshell"
