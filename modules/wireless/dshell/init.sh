#!/usr/bin/env bash

# shellcheck disable=SC2317,SC2329
dshell_wireless_network_status() {
  nmcli --fields NAME,TYPE,DEVICE connection show --active
}

dshell_register_group "Wireless network controls"
dshell_register_command "status" "fn dshell_wireless_network_status" "" \
  "List active network connections"
dshell_register_command "toggle" "ipc popup toggle wireless" "" \
  "Toggle wireless popup"
