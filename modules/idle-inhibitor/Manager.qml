pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
  id: manager

  property bool inhibited: false

  function enable() {
    inhibited = true
  }

  function disable() {
    inhibited = false
  }

  function toggle() {
    if (inhibited) disable()
    else enable()
  }

  IpcHandler {
    target: "idle"

    function enable(): string {
      manager.enable()
      return "Idle inhibitor is now enabled"
    }
    function disable(): string {
      manager.disable()
      return "Idle inhibitor is now disabled"
    }
    function toggle(): string {
      return manager.inhibited ? disable() : enable()
    }
    function state(): bool { return manager.inhibited }
  }

}
