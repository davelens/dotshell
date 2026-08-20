#!/usr/bin/env bash

display_text_size() {
  if [[ $# -eq 0 ]]; then
    ipc display currentTextSize
  else
    ipc display setTextSize "$1"
  fi
}

dshell_register_group "Display controls"
dshell_register_command "toggle" "ipc popup toggle display" "" \
  "Toggle display popup"
dshell_register_command "text-size" "fn display_text_size" "[px]" \
  "Show or set display text size"
