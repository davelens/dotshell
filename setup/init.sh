#!/usr/bin/env bash
set -e

DOTSHELL_REPO_HOME="$(cd "$(dirname "$(dirname "${BASH_SOURCE[0]}")")" && pwd)"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
DESKTOP_USER="$(id -un)"

if [[ "$(id -u)" -eq 0 ]]; then
  echo "error: run this script as your desktop user, without sudo" >&2
  exit 1
fi

# shellcheck source=/dev/null
. "$DOTSHELL_REPO_HOME/setup/lib/platform.sh"
load_platform "$DOTSHELL_REPO_HOME/setup"
platform_install_packages

# Enable i2c for ddcutil (external monitor brightness).
if getent group i2c >/dev/null && ! id -nG "$DESKTOP_USER" | tr ' ' '\n' | grep -qx i2c; then
  echo "==> Adding user to i2c group for ddcutil..."
  sudo usermod -aG i2c "$DESKTOP_USER"
  echo "    Note: You may need to log out and back in for this to take effect."
fi

if ! lsmod | grep -q '^i2c_dev '; then
  echo "==> Loading i2c-dev kernel module..."
  sudo modprobe i2c-dev
fi

if [[ ! -f /etc/modules-load.d/i2c-dev.conf ]]; then
  echo "==> Configuring i2c-dev to load on boot..."
  echo "i2c-dev" | sudo tee /etc/modules-load.d/i2c-dev.conf >/dev/null
fi

echo "==> Symlinking dotshell config..."
mkdir -p "$XDG_CONFIG_HOME"
ln -sfn "$DOTSHELL_REPO_HOME" "$XDG_CONFIG_HOME/dotshell"

echo "==> Installing \`dshell\`..."
mkdir -p "$HOME/.local/bin"
ln -sfn "$DOTSHELL_REPO_HOME/bin/dshell" "$HOME/.local/bin/dshell"
mkdir -p "$XDG_DATA_HOME/bash-completion/completions"
ln -sfn "$DOTSHELL_REPO_HOME/bin/dshell-completion.bash" \
  "$XDG_DATA_HOME/bash-completion/completions/dshell"

platform_setup_service

echo "==> Installing dotshell settings desktop entry..."
mkdir -p "$XDG_DATA_HOME/applications"
rm -f "$XDG_DATA_HOME/applications/quickshell-settings.desktop"
cat >"$XDG_DATA_HOME/applications/dotshell-settings.desktop" <<EOF
[Desktop Entry]
Name=Settings
Comment=Open our shell settings panel
Exec=qs -p $XDG_CONFIG_HOME/dotshell ipc call settings toggle
Icon=preferences-system
Type=Application
Categories=Settings;
EOF

update-desktop-database "$XDG_DATA_HOME/applications"

if pgrep -x mako >/dev/null; then
  echo "==> Mako is running; stop it before using dotshell notifications"
fi

echo "==> dotshell installation complete!"
echo
echo "NOTE: If using external monitors with brightness control, log out/in for i2c group changes to take effect"
