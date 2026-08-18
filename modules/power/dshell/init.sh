#!/usr/bin/env bash

dshell_register_group "Power menu"
dshell_register_command "toggle" "ipc overlay toggle power" "" "Toggle power menu"
dshell_register_command "open" "ipc overlay open power" "" "Open power menu"
dshell_register_command "close" "ipc overlay close power" "" "Close power menu"
