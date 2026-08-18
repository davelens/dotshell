#!/usr/bin/env bash

dshell_register_group "Notification panel and history"
dshell_register_command "toggle" "ipc overlay toggle notifications" "" \
  "Toggle notification panel"
dshell_register_command "open" "ipc overlay open notifications" "" \
  "Open notification panel"
dshell_register_command "close" "ipc overlay close notifications" "" \
  "Close notification panel"
dshell_register_command "dismiss" "ipc notifications dismiss" "<id>" \
  "Dismiss a notification by id"
dshell_register_command "clear-all" "ipc notifications clearAll" "" \
  "Clear notification history"
dshell_register_command "listen" "listen notifications received" "" \
  "Stream new local notifications"
dshell_register_command "remote set" "ipc notifications setRemoteHost" "<host>" \
  "Set the remote notification SSH host"
dshell_register_command "remote clear" "ipc notifications clearRemoteHost" "" \
  "Clear the remote notification SSH host"
