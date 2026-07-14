#!/usr/bin/env bash

perform_action() {
  case "$1" in
    suspend) exec loginctl suspend ;;
    reboot) exec loginctl reboot ;;
    shutdown) exec loginctl poweroff ;;
    *)
      echo "error: usage: power-action {suspend|reboot|shutdown}" >&2
      return 2
      ;;
  esac
}
