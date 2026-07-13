pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs

Singleton {
  id: powerManager

  // -- Persisted settings (command strings, profile-independent) -----------

  property alias lockCommand: generalAdapter.lockCommand
  property alias suspendCommand: generalAdapter.suspendCommand
  property alias logoutCommand: generalAdapter.logoutCommand
  property alias rebootCommand: generalAdapter.rebootCommand
  property alias shutdownCommand: generalAdapter.shutdownCommand

  ModuleConfig {
    moduleId: "power"
    scope: "general"
    adapter: JsonAdapter {
      id: generalAdapter
      property string lockCommand: "loginctl lock-session"
      property string suspendCommand: "loginctl suspend"
      property string logoutCommand: "swaymsg exit"
      property string rebootCommand: "loginctl reboot"
      property string shutdownCommand: "loginctl poweroff"
    }
    onLoaded: text => powerManager.migrateSystemdDefaults(text)
  }

  // Migrate only the former built-in defaults; never replace user commands.
  function migrateSystemdDefaults(text) {
    if (!text || text.trim() === "") return
    try {
      var config = JSON.parse(text)
      if (config.suspendCommand === "systemctl suspend") {
        generalAdapter.suspendCommand = "loginctl suspend"
      }
      if (config.rebootCommand === "systemctl reboot") {
        generalAdapter.rebootCommand = "loginctl reboot"
      }
      if (config.shutdownCommand === "systemctl poweroff") {
        generalAdapter.shutdownCommand = "loginctl poweroff"
      }
    } catch (error) {
      console.error("[PowerManager] Failed to migrate command defaults:", error)
    }
  }

  // -- Runtime state -------------------------------------------------------

  readonly property bool menuOpen: OverlayManager.isOpen("power")
  onMenuOpenChanged: {
    pendingAction = ""
    if (menuOpen) uptimeProc.running = true
  }
  property string pendingAction: ""
  property string username: ""
  property string uptime: ""

  // -- Actions metadata ----------------------------------------------------

  readonly property var actions: [
    { id: "lock",     label: "Lock",     icon: "󰌾" },
    { id: "suspend",  label: "Suspend",  icon: "󰤄" },
    { id: "logout",   label: "Logout",   icon: "󰍃" },
    { id: "reboot",   label: "Reboot",   icon: "󰜉" },
    { id: "shutdown", label: "Shutdown", icon: "󰐥" }
  ]

  // Map action id to its user-configured command
  function getCommand(actionId) {
    switch (actionId) {
      case "lock":     return lockCommand
      case "suspend":  return suspendCommand
      case "logout":   return logoutCommand
      case "reboot":   return rebootCommand
      case "shutdown": return shutdownCommand
      default:         return ""
    }
  }

  // Description shown in the confirmation dialog
  function getDescription(actionId) {
    switch (actionId) {
      case "lock":     return "This will lock your session."
      case "suspend":  return "This will suspend your computer."
      case "logout":   return "This will end your session."
      case "reboot":   return "This will reboot your computer."
      case "shutdown": return "This will shut down your computer."
      default:         return ""
    }
  }

  // -- Public API ----------------------------------------------------------

  function toggle() {
    OverlayManager.toggle("power")
  }

  function open() {
    OverlayManager.open("power")
  }

  function close() {
    OverlayManager.close("power")
  }

  function requestAction(actionId) {
    pendingAction = actionId
  }

  function confirmAction() {
    var cmd = getCommand(pendingAction)
    if (cmd) {
      actionProc.command = ["sh", "-c", cmd]
      actionProc.running = true
    }
    close()
  }

  function cancelAction() {
    pendingAction = ""
  }

  // -- Processes -----------------------------------------------------------

  // Get username at startup
  Process {
    id: whoamiProc
    command: ["whoami"]
    running: true
    stdout: SplitParser {
      onRead: data => { powerManager.username = data.trim() }
    }
  }

  // Get uptime when menu opens
  Process {
    id: uptimeProc
    command: ["uptime", "-p"]
    running: false
    stdout: SplitParser {
      onRead: data => { powerManager.uptime = data.trim() }
    }
  }

  // Execute the selected power action
  Process {
    id: actionProc
    running: false
  }

  Component.onCompleted: OverlayManager.register("power", "Power menu")
}
