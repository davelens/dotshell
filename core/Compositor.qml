pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import ".."

// Core compositor abstraction. Auto-detects the active compositor (sway/niri)
// and provides command helpers so modules don't hardcode compositor commands.
Singleton {
  id: compositor

  // Detected compositor from environment ("sway" or "niri")
  readonly property string resolvedBackend: {
    var swaysock = Quickshell.env("SWAYSOCK")
    if (swaysock) return "sway"
    var i3sock = Quickshell.env("I3SOCK")
    if (i3sock) return "sway"
    var niriSocket = Quickshell.env("NIRI_SOCKET")
    if (niriSocket) return "niri"
    return "sway"
  }

  // Emitted when fetchOutputs() completes with JSON output data
  signal outputsFetched(string json)

  // Emitted when applyPosition() finishes (success or failure)
  signal positionApplied(bool success)

  // Rotate a display. transform values: "normal", "90", "180", "270"
  function setTransform(name, transform) {
    if (!name) return
    if (resolvedBackend === "niri") {
      niriTransformProc.command = ["niri", "msg", "output", name, "transform", transform]
      niriTransformProc.running = true
    } else {
      swayTransformProc.command = ["swaymsg", "output", name, "transform", transform]
      swayTransformProc.running = true
    }
  }

  // Focus a window by app_id / desktop entry
  function focusWindow(appId) {
    if (!appId) return
    if (resolvedBackend === "niri") {
      niriFocusProc.command = ["niri", "msg", "action", "focus-window", "--app-id", appId]
      niriFocusProc.running = true
    } else {
      swayFocusProc.command = ["swaymsg", "[app_id=" + appId + "] focus"]
      swayFocusProc.running = true
    }
  }

  // Set monitor position (one call per output)
  function applyPosition(name, x, y) {
    if (!name) return
    if (resolvedBackend === "niri") {
      niriPositionProc.command = ["niri", "msg", "output", name, "position", "set",
        String(x), String(y)]
      niriPositionProc.running = true
    } else {
      swayPositionProc.command = ["swaymsg", "output", name, "pos", String(x), String(y)]
      swayPositionProc.running = true
    }
  }

  // Fetch all outputs (async). Result delivered via outputsFetched signal.
  function fetchOutputs() {
    if (resolvedBackend === "niri") {
      niriFetchProc.output = ""
      niriFetchProc.running = true
    } else {
      swayFetchProc.output = ""
      swayFetchProc.running = true
    }
  }

  // Sway processes
  Process {
    id: swayTransformProc
    running: false
  }

  Process {
    id: swayFocusProc
    running: false
  }

  Process {
    id: swayPositionProc
    running: false
    onExited: (exitCode) => {
      compositor.positionApplied(exitCode === 0)
    }
  }

  Process {
    id: swayFetchProc
    property string output: ""
    command: ["swaymsg", "-t", "get_outputs"]
    running: false
    stdout: SplitParser {
      splitMarker: ""
      onRead: data => { swayFetchProc.output += data }
    }
    onExited: (exitCode) => {
      if (exitCode === 0) {
        compositor.outputsFetched(swayFetchProc.output)
      }
      swayFetchProc.output = ""
    }
  }

  // Niri processes
  Process {
    id: niriTransformProc
    running: false
  }

  Process {
    id: niriFocusProc
    running: false
  }

  Process {
    id: niriPositionProc
    running: false
    onExited: (exitCode) => {
      compositor.positionApplied(exitCode === 0)
    }
  }

  Process {
    id: niriFetchProc
    property string output: ""
    command: ["niri", "msg", "-j", "outputs"]
    running: false
    stdout: SplitParser {
      splitMarker: ""
      onRead: data => { niriFetchProc.output += data }
    }
    onExited: (exitCode) => {
      if (exitCode === 0) {
        compositor.outputsFetched(niriFetchProc.output)
      }
      niriFetchProc.output = ""
    }
  }
}
