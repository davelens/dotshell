import QtQuick
import Quickshell
import Quickshell.Io

// Niri workspace backend using persistent event stream.
// Listens to `niri msg event-stream` for real-time updates instead of polling.
Item {
  id: backend
  visible: false

  // Normalized workspace list: [{ name, focused, hasWindows }]
  property var workspaces: []

  // Auto-discover niri socket if not in environment
  readonly property string niriSocket: Quickshell.env("NIRI_SOCKET") || ""
  property string discoveredSocket: ""
  readonly property string socket: niriSocket || discoveredSocket

  // Socket discovery (runs once at startup if NIRI_SOCKET is unset)
  Process {
    id: discoverProc
    command: ["sh", "-c", "ls /run/user/$(id -u)/niri.*.sock 2>/dev/null | head -1"]
    running: !backend.niriSocket

    stdout: SplitParser {
      onRead: line => {
        if (line.trim()) backend.discoveredSocket = line.trim()
      }
    }
  }

  // Fetch full workspace state (used on startup and when event stream signals changes)
  function refresh() {
    if (backend.socket !== "" && !pollProc.running) pollProc.running = true
  }

  // Initial fetch + start event stream when socket becomes available
  onSocketChanged: {
    if (socket !== "") {
      refresh()
      startEventStream()
    }
  }

  Component.onCompleted: {
    if (socket !== "") {
      refresh()
      startEventStream()
    }
  }

  function startEventStream() {
    if (eventProc.running || backend.socket === "") return
    eventProc.command = ["sh", "-c",
      "NIRI_SOCKET='" + backend.socket + "' niri msg event-stream"]
    eventProc.running = true
  }

  // Persistent event stream process
  Process {
    id: eventProc

    stdout: SplitParser {
      onRead: line => {
        // Each line is a JSON object with an event type key
        // Workspace-relevant events: WorkspacesChanged, WorkspaceActivated,
        // WindowOpenedOrChanged, WindowClosed, WindowsChanged, WindowFocusChanged
        var trimmed = line.trim()
        if (trimmed === "" || trimmed === "{" || trimmed === "}") return

        // Event lines look like: "EventName": { ... }
        // We only need to detect the event type, not parse the payload
        if (trimmed.indexOf("WorkspacesChanged") >= 0 ||
            trimmed.indexOf("WorkspaceActivated") >= 0 ||
            trimmed.indexOf("WindowOpenedOrChanged") >= 0 ||
            trimmed.indexOf("WindowClosed") >= 0 ||
            trimmed.indexOf("WindowsChanged") >= 0 ||
            trimmed.indexOf("WindowFocusChanged") >= 0) {
          backend.refresh()
        }
      }
    }

    onExited: (code) => {
      // Restart event stream after a brief delay if it dies unexpectedly
      restartTimer.start()
    }
  }

  Timer {
    id: restartTimer
    interval: 2000
    repeat: false
    onTriggered: backend.startEventStream()
  }

  // One-shot workspace fetch process
  Process {
    id: pollProc
    command: ["sh", "-c", "NIRI_SOCKET='" + backend.socket + "' niri msg -j workspaces"]
    property string buffer: ""

    stdout: SplitParser {
      onRead: line => { pollProc.buffer += line }
    }

    onExited: (code) => {
      if (code === 0 && pollProc.buffer) {
        backend.parseWorkspaces(pollProc.buffer)
      }
      pollProc.buffer = ""
    }
  }

  function parseWorkspaces(json) {
    try {
      var data = JSON.parse(json)
      var arr = []
      for (var i = 0; i < data.length; i++) {
        var ws = data[i]
        // Niri uses idx for ordering and may have optional names
        var name = ws.name || String(ws.idx)
        arr.push({
          name: name,
          focused: ws.is_focused || false,
          hasWindows: ws.active_window_id !== null
        })
      }
      arr.sort(function(a, b) {
        return parseInt(a.name) - parseInt(b.name)
      })
      workspaces = arr
    } catch (e) {
      console.error("[NiriBackend] Failed to parse workspaces:", e)
    }
  }

  function focusWorkspace(name) {
    focusProc.command = ["sh", "-c",
      "NIRI_SOCKET='" + backend.socket + "' niri msg action focus-workspace " + name]
    focusProc.running = true
  }

  Process {
    id: focusProc
  }

  // Find a single workspace by name
  function findWorkspace(name) {
    for (var i = 0; i < workspaces.length; i++) {
      if (workspaces[i].name === name) return workspaces[i]
    }
    return null
  }
}
