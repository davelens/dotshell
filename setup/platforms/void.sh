#!/usr/bin/env bash

platform_service_description() {
  echo "Quickshell turnstile/runit user service"
}

platform_install_packages() {
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

  if [[ -d /etc/sv/bluetoothd ]]; then
    echo "==> Enabling the Void bluetoothd service..."
    sudo ln -sfn /etc/sv/bluetoothd /var/service/bluetoothd
  fi

  local group
  for group in network bluetooth; do
    if getent group "$group" >/dev/null \
        && ! id -nG "$DESKTOP_USER" | tr ' ' '\n' | grep -qx "$group"; then
      echo "==> Adding $DESKTOP_USER to the Void $group group..."
      sudo usermod -aG "$group" "$DESKTOP_USER"
    fi
  done
}

platform_setup_service() {
  local service_dir="$HOME/.config/service/quickshell"

  if ! command -v chpst >/dev/null 2>&1; then
    echo "error: chpst is required for the Void runit service" >&2
    exit 1
  fi

  echo "==> Setting up Quickshell turnstile/runit user service..."
  mkdir -p "$service_dir"
  ln -sfn "$DOTSHELL_REPO_HOME/setup/quickshell.run" "$service_dir/run"

  if command -v sv >/dev/null 2>&1 && sv status "$service_dir" >/dev/null 2>&1; then
    sv restart "$service_dir"
  else
    echo "    Service installed; turnstile will start it shortly or on the next login."
  fi
}

platform_stop_service() {
  local service_dir="$HOME/.config/service/quickshell"

  echo "==> Stopping Quickshell runit service..."
  if command -v sv >/dev/null 2>&1; then
    sv down "$service_dir" 2>/dev/null || true
  fi
  if [[ -L "$service_dir/run" ]]; then
    rm "$service_dir/run"
  fi
  if [[ -d "$service_dir" ]]; then
    rmdir "$service_dir" 2>/dev/null || true
  fi
}

platform_uninstall_package() {
  if xbps-query quickshell >/dev/null 2>&1; then
    echo "==> Uninstalling quickshell..."
    sudo xbps-remove -y quickshell
  else
    echo "==> Quickshell package not found, skipping"
  fi
}
