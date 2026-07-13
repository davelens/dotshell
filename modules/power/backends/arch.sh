#!/usr/bin/env bash

perform_action() {
  case "$1" in
    suspend) exec systemctl suspend ;;
    reboot) exec systemctl reboot ;;
    shutdown) exec systemctl poweroff ;;
    *)
      echo "error: usage: power-action {suspend|reboot|shutdown}" >&2
      return 2
      ;;
  esac
}
