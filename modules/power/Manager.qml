pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../.."

Singleton {
  id: powerManager

  // -- Persisted settings (command strings) --------------------------------

  property alias lockCommand: settingsAdapter.lockCommand
  property alias suspendCommand: settingsAdapter.suspendCommand
  property alias logoutCommand: settingsAdapter.logoutCommand
  property alias rebootCommand: settingsAdapter.rebootCommand
  property alias shutdownCommand: settingsAdapter.shutdownCommand

  // File-based persistence
  readonly property string statePath: DataManager.getStatePath("power")
  readonly property string defaultsPath: DataManager.getDefaultsPath("power")
  property bool fileReady: false

  // Copy defaults if state file doesn't exist
  Process {
    id: ensureDefaults
    command: ["sh", "-c", "test -f '" + powerManager.statePath + "' || cp '" + powerManager.defaultsPath + "' '" + powerManager.statePath + "'"]
    running: DataManager.ready
    onExited: { powerManager.fileReady = true }
  }

  FileView {
    id: settingsFile
    path: powerManager.fileReady ? powerManager.statePath : ""

    watchChanges: true
    onFileChanged: reload()
    onAdapterUpdated: writeAdapter()

    JsonAdapter {
      id: settingsAdapter
      property string lockCommand: "loginctl lock-session"
      property string suspendCommand: "systemctl suspend"
      property string logoutCommand: "swaymsg exit"
      property string rebootCommand: "systemctl reboot"
      property string shutdownCommand: "systemctl poweroff"
    }
  }

  // -- Runtime state -------------------------------------------------------

  property bool menuOpen: false
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
    if (menuOpen) close()
    else open()
  }

  function open() {
    pendingAction = ""
    uptimeProc.running = true
    menuOpen = true
  }

  function close() {
    menuOpen = false
    pendingAction = ""
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

  // -- IPC -----------------------------------------------------------------

  IpcHandler {
    target: "power"

    function toggle(): void { powerManager.toggle() }
    function open(): void { powerManager.open() }
    function close(): void { powerManager.close() }
  }
}
