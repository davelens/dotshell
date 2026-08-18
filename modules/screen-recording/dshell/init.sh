#!/usr/bin/env bash

dshell_register_group "Screen recording file browser"
dshell_register_command "files toggle" "ipc overlay toggle screen-recording" "" \
  "Toggle the screen recording file browser"
dshell_register_command "files open" "ipc overlay open screen-recording" "" \
  "Open the screen recording file browser"
dshell_register_command "files close" "ipc overlay close screen-recording" "" \
  "Close the screen recording file browser"
