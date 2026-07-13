#!/usr/bin/env bash

platform_service_description() {
  echo "dotshell turnstile/runit user services"
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
    desktop-file-utils \
    lxqt-policykit

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

platform_setup_user_service() {
  local name="$1" run_script="$2"
  local service_dir="$HOME/.config/service/$name"

  mkdir -p "$service_dir"
  ln -sfn "$run_script" "$service_dir/run"

  if command -v sv >/dev/null 2>&1 && sv status "$service_dir" >/dev/null 2>&1; then
    sv restart "$service_dir"
  else
    echo "    $name installed; turnstile will start it shortly or on the next login."
  fi
}

platform_setup_service() {
  if ! command -v chpst >/dev/null 2>&1; then
    echo "error: chpst is required for the Void runit service" >&2
    exit 1
  fi

  echo "==> Setting up turnstile/runit user services..."
  platform_setup_user_service quickshell "$DOTSHELL_REPO_HOME/setup/quickshell.run"
  platform_setup_user_service lxqt-policykit "$DOTSHELL_REPO_HOME/setup/lxqt-policykit.run"
}

platform_stop_service() {
  local name service_dir

  echo "==> Stopping dotshell runit user services..."
  for name in quickshell lxqt-policykit; do
    service_dir="$HOME/.config/service/$name"
    if command -v sv >/dev/null 2>&1; then
      sv down "$service_dir" 2>/dev/null || true
    fi
    if [[ -L "$service_dir/run" ]]; then
      rm "$service_dir/run"
    fi
    if [[ -d "$service_dir" ]]; then
      rmdir "$service_dir" 2>/dev/null || true
    fi
  done
}

platform_uninstall_package() {
  if xbps-query quickshell >/dev/null 2>&1; then
    echo "==> Uninstalling quickshell..."
    sudo xbps-remove -y quickshell
  else
    echo "==> Quickshell package not found, skipping"
  fi
}
