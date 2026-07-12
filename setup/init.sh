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

if [[ ! -r /etc/os-release ]]; then
  echo "error: cannot detect the Linux distribution (/etc/os-release is missing)" >&2
  exit 1
fi

# shellcheck source=/dev/null
. /etc/os-release
DISTRO="${ID:-}"

install_arch_packages() {
  echo "==> Installing Quickshell and dependencies with pacman..."
  sudo pacman -S --needed --noconfirm \
    bluez bluez-utils \
    brightnessctl \
    ddcutil \
    networkmanager \
    pipewire wireplumber \
    pacman-contrib \
    gpu-screen-recorder \
    wf-recorder \
    ttf-hack-nerd ttf-dejavu \
    libnotify \
    ffmpeg \
    jq \
    desktop-file-utils

  if ! command -v paru >/dev/null 2>&1; then
    echo "error: paru is required to install Quickshell on Arch" >&2
    exit 1
  fi
  paru -S --needed --noconfirm quickshell
}

install_void_packages() {
  echo "==> Installing Quickshell and dependencies with XBPS..."
  sudo xbps-install -Sy \
    quickshell \
    bluez libspa-bluetooth \
    brightnessctl \
    ddcutil \
    NetworkManager \
    pipewire wireplumber \
    gpu-screen-recorder \
    wf-recorder \
    nerd-fonts-ttf dejavu-fonts-ttf \
    libnotify \
    ffmpeg \
    jq \
    desktop-file-utils

  # bluetoothctl needs the system daemon. The base Void setup already runs
  # D-Bus and NetworkManager; enabling an existing service is idempotent.
  if [[ -d /etc/sv/bluetoothd ]]; then
    echo "==> Enabling the Void bluetoothd service..."
    sudo ln -sfn /etc/sv/bluetoothd /var/service/bluetoothd
  fi

  echo "==> Granting access to Void network and Bluetooth devices..."
  sudo usermod -aG network,bluetooth "$DESKTOP_USER"
}

case "$DISTRO" in
  arch)
    install_arch_packages
    ;;
  void)
    install_void_packages
    ;;
  *)
    echo "error: unsupported distribution '$DISTRO' (supported: Arch Linux, Void Linux)" >&2
    exit 1
    ;;
esac

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

setup_arch_service() {
  echo "==> Setting up Quickshell systemd user service..."
  systemctl --user daemon-reload
  systemctl --user enable "$DOTSHELL_REPO_HOME/setup/quickshell.service"
  systemctl --user restart quickshell.service
}

setup_void_service() {
  local service_dir="$HOME/.config/service/quickshell"

  if ! command -v chpst >/dev/null 2>&1; then
    echo "error: chpst is required for the Void runit service" >&2
    exit 1
  fi

  echo "==> Setting up Quickshell turnstile/runit user service..."
  mkdir -p "$service_dir"
  ln -sfn "$DOTSHELL_REPO_HOME/setup/quickshell.run" "$service_dir/run"

  # An active turnstile runsvdir discovers the service automatically. Restart
  # it when already supervised; otherwise it starts on the next login.
  if command -v sv >/dev/null 2>&1 && sv status "$service_dir" >/dev/null 2>&1; then
    sv restart "$service_dir"
  else
    echo "    Service installed; turnstile will start it shortly or on the next login."
  fi
}

case "$DISTRO" in
  arch) setup_arch_service ;;
  void) setup_void_service ;;
esac

echo "==> Installing settings panel desktop entry..."
mkdir -p "$XDG_DATA_HOME/applications"
cat >"$XDG_DATA_HOME/applications/quickshell-settings.desktop" <<EOF
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
  echo "==> Mako is running; stop it before using Quickshell notifications"
fi

echo "==> Quickshell installation complete!"
echo
echo "NOTE: If using external monitors with brightness control, log out/in for i2c group changes to take effect"
