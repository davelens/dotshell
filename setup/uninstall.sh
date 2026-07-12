#!/usr/bin/env bash
set -e

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

if [[ -r /etc/os-release ]]; then
  # shellcheck source=/dev/null
  . /etc/os-release
fi
DISTRO="${ID:-unknown}"
VOID_SERVICE_DIR="$HOME/.config/service/quickshell"

echo "This will remove:"
case "$DISTRO" in
  arch) echo "  - Quickshell systemd user service" ;;
  void) echo "  - Quickshell turnstile/runit user service" ;;
  *) echo "  - Quickshell user service (when recognized)" ;;
esac
echo "  - $XDG_CONFIG_HOME/dotshell (symlink)"
echo "  - $XDG_DATA_HOME/dotshell (profile data)"
echo "  - $XDG_DATA_HOME/applications/quickshell-settings.desktop"
echo "  - $XDG_RUNTIME_DIR/quickshell (runtime logs)"
echo "  - Quickshell package"
echo
read -rp "Continue? [y/N] " confirm
[[ "$confirm" =~ ^[Yy]$ ]] || {
  echo "Aborted."
  exit 0
}

case "$DISTRO" in
  arch)
    echo "==> Stopping Quickshell systemd service..."
    systemctl --user stop quickshell.service 2>/dev/null || true
    systemctl --user disable quickshell.service 2>/dev/null || true
    systemctl --user daemon-reload
    ;;
  void)
    echo "==> Stopping Quickshell runit service..."
    if command -v sv >/dev/null 2>&1; then
      sv down "$VOID_SERVICE_DIR" 2>/dev/null || true
    fi
    if [[ -L "$VOID_SERVICE_DIR/run" ]]; then
      rm "$VOID_SERVICE_DIR/run"
    fi
    if [[ -d "$VOID_SERVICE_DIR" ]]; then
      rmdir "$VOID_SERVICE_DIR" 2>/dev/null || true
    fi
    ;;
esac

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

if [[ -f "$XDG_DATA_HOME/applications/quickshell-settings.desktop" ]]; then
  echo "==> Removing desktop entry"
  rm "$XDG_DATA_HOME/applications/quickshell-settings.desktop"
fi

if [[ -d "$XDG_RUNTIME_DIR/quickshell" ]]; then
  echo "==> Removing runtime directory: $XDG_RUNTIME_DIR/quickshell"
  rm -rf "$XDG_RUNTIME_DIR/quickshell"
fi

case "$DISTRO" in
  arch)
    if pacman -Qi quickshell-git &>/dev/null; then
      echo "==> Uninstalling quickshell-git..."
      sudo pacman -Rns --noconfirm quickshell-git
    elif pacman -Qi quickshell &>/dev/null; then
      echo "==> Uninstalling quickshell..."
      sudo pacman -Rns --noconfirm quickshell
    else
      echo "==> Quickshell package not found, skipping"
    fi
    ;;
  void)
    if xbps-query quickshell >/dev/null 2>&1; then
      echo "==> Uninstalling quickshell..."
      sudo xbps-remove -y quickshell
    else
      echo "==> Quickshell package not found, skipping"
    fi
    ;;
  *)
    echo "==> Unknown distribution; leaving the Quickshell package installed"
    ;;
esac

echo "==> Uninstall complete."
echo
echo "Note: The dotshell repo itself was not removed."
echo "  To delete it: rm -rf ~/Repositories/davelens/dotshell"
