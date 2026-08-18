#!/usr/bin/env bash

dshell_register_group "Idle inhibitor control"
dshell_register_command "enable" "ipc idle enable" "" "Enable idle inhibitor"
dshell_register_command "disable" "ipc idle disable" "" "Disable idle inhibitor"
dshell_register_command "toggle" "ipc idle toggle" "" "Toggle idle inhibitor"
dshell_register_command "state" "ipc idle state" "" "Show idle inhibitor state"
