import QtQuick
import Quickshell.I3
import Quickshell.Io

// Sway/i3 workspace backend using native Quickshell.I3 API.
// Uses I3.rawEvent for event-driven updates instead of polling.
Item {
  id: backend
  visible: false

  // Fresh occupancy map from `swaymsg -t get_workspaces`
  // workspace name -> bool (has windows)
  property var windowState: ({})

  function hasWindowsFromIpc(ipc) {
    if (!ipc) return false
    var hasTiled = ipc.representation && /\[(.+)\]/.test(ipc.representation)
    var hasFloating = ipc.floating_nodes && ipc.floating_nodes.length > 0
    return hasTiled || hasFloating
  }

  // Normalized workspace list: [{ name, focused, hasWindows }]
  readonly property var workspaces: {
    var _ = I3.workspaces.values.length
    var _w = windowState
    var arr = []
    var wsValues = I3.workspaces.values
    for (var i = 0; i < wsValues.length; i++) {
      var ws = wsValues[i]
      var hasWin = windowState[ws.name]
      if (hasWin === undefined) hasWin = hasWindowsFromIpc(ws.lastIpcObject)
      arr.push({ name: ws.name, focused: ws.focused, hasWindows: hasWin })
    }
    arr.sort(function(a, b) {
      return parseInt(a.name) - parseInt(b.name)
    })
    return arr
  }

  // Listen for Sway IPC events that affect workspace occupancy
  Connections {
    target: I3
    function onRawEvent(event) {
      if (event.type === "window" || event.type === "workspace" || event.type === "move") {
        if (!refreshProc.running) refreshProc.running = true
      }
    }
    function onConnected() {
      if (!refreshProc.running) refreshProc.running = true
    }
  }

  // Initial refresh at startup
  Component.onCompleted: {
    refreshProc.running = true
  }

  Process {
    id: refreshProc
    command: ["swaymsg", "-t", "get_workspaces"]
    property string buffer: ""

    stdout: SplitParser {
      onRead: line => { refreshProc.buffer += line }
    }

    onExited: code => {
      if (code === 0 && refreshProc.buffer) {
        try {
          var data = JSON.parse(refreshProc.buffer)
          var nextState = ({})
          for (var i = 0; i < data.length; i++) {
            var ipc = data[i]
            var name = ipc.name
            if (!name) continue
            nextState[name] = backend.hasWindowsFromIpc(ipc)
          }
          backend.windowState = nextState
        } catch (e) {
          console.error("[I3Backend] Failed to parse sway workspaces:", e)
        }
      }
      refreshProc.buffer = ""
    }
  }

  function focusWorkspace(name) {
    I3.dispatch("workspace " + name)
  }

  // Find a single workspace by name
  function findWorkspace(name) {
    for (var i = 0; i < workspaces.length; i++) {
      if (workspaces[i].name === name) return workspaces[i]
    }
    return null
  }
}
