#!/usr/bin/env bash

platform_service_description() {
  echo "Quickshell systemd user service"
}

platform_install_packages() {
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

platform_setup_service() {
  echo "==> Setting up Quickshell systemd user service..."
  systemctl --user daemon-reload
  systemctl --user enable "$DOTSHELL_REPO_HOME/setup/quickshell.service"
  systemctl --user restart quickshell.service
}

platform_stop_service() {
  echo "==> Stopping Quickshell systemd service..."
  systemctl --user stop quickshell.service 2>/dev/null || true
  systemctl --user disable quickshell.service 2>/dev/null || true
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
    echo "==> Quickshell package not found, skipping"
  fi
}
