#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
manager="$repo_root/modules/display/Manager.qml"
compositor="$repo_root/core/Compositor.qml"
manifest="$repo_root/modules/display/module.json"
bootstrap="$repo_root/modules/display/Clamshell.qml"

# The policy starts with the shell, even when the display popup stays closed.
grep -Fq '"rootComponents": ["Clamshell.qml"]' "$manifest"
grep -Fq 'property var manager: DisplayManager' "$bootstrap"

# Lid state comes from login1 via portable gdbus, with an initial read and
# event-driven PropertiesChanged monitor.
grep -Fq '["gdbus", "call", "--system", "--dest", "org.freedesktop.login1"' "$manager"
grep -Fq '"org.freedesktop.DBus.Properties.Get", "org.freedesktop.login1.Manager", "LidClosed"]' "$manager"
grep -Fq '["gdbus", "monitor", "--system", "--dest", "org.freedesktop.login1"' "$manager"
grep -Fq 'stdout: SplitParser {' "$manager"
grep -Fq 'line.indexOf("PropertiesChanged")' "$manager"
if grep -Fq 'busctl' "$manager"; then
  exit 1
fi

# Source-contract markers for internal detection and each policy branch.
grep -Fq '/^(eDP|LVDS|DSI)-/' "$manager"
grep -Fq 'else if (outputs[i].active) activeExternalCount++' "$manager"
grep -Fq 'if (lidClosed && activeExternalCount > 0)' "$manager"
grep -Fq 'if (owned && !owned.active)' "$manager"
if grep -Fq 'activeExternalCount === 0 && activeCount === 0' "$manager"; then
  echo 'clamshell policy must not mutate outputs during a zero-output hotplug transient' >&2
  exit 1
fi
grep -Fq 'if (!lidStateKnown || _outputPowerPending) return' "$manager"
grep -Fq 'if (!active && activeCount <= 1) return' "$manager"

# Both compositor backends retain their output query and power commands.
grep -Fq '["niri", "msg", "output", name, active ? "on" : "off"]' "$compositor"
grep -Fq '["swaymsg", "output", name, active ? "enable" : "disable"]' "$compositor"
grep -Fq 'command: ["swaymsg", "-t", "get_outputs"]' "$compositor"
grep -Fq 'command: ["niri", "msg", "-j", "outputs"]' "$compositor"

echo 'display clamshell source contract tests passed'
