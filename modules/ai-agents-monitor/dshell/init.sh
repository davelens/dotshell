#!/usr/bin/env bash

# Registrations are relative to the containing module id.
dshell_register_group "AI agent monitor snapshots"
dshell_register_command "current" "ipc --any-display agents current" "" \
  "Print the current local AI agent snapshot"
dshell_register_command "listen" "listen agents snapshot" "" \
  "Stream local AI agent snapshots"
