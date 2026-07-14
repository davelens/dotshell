#!/usr/bin/env bash

platform_service_description() {
  echo "dotshell systemd user service"
}

platform_install_packages() {
  echo "==> Installing dotshell runtime and dependencies with pacman..."
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
    echo "error: paru is required to install the Quickshell runtime on Arch" >&2
    exit 1
  fi
  paru -S --needed --noconfirm quickshell
}

platform_setup_service() {
  echo "==> Setting up dotshell systemd user service..."
  systemctl --user disable --now quickshell.service 2>/dev/null || true
  systemctl --user daemon-reload
  systemctl --user enable "$DOTSHELL_REPO_HOME/setup/dotshell.service"
  systemctl --user restart dotshell.service
}

platform_stop_service() {
  echo "==> Stopping dotshell systemd service..."
  for service in dotshell.service quickshell.service; do
    systemctl --user stop "$service" 2>/dev/null || true
    systemctl --user disable "$service" 2>/dev/null || true
  done
  systemctl --user daemon-reload
}

platform_uninstall_package() {
  if pacman -Qi quickshell-git &>/dev/null; then
    echo "==> Uninstalling quickshell-git..."
    sudo pacman -Rns --noconfirm quickshell-git
  elif pacman -Qi quickshell &>/dev/null; then
    echo "==> Uninstalling quickshell..."
    sudo pacman -Rns --noconfirm quickshell
  else
    echo "==> Quickshell runtime package not found, skipping"
  fi
}
