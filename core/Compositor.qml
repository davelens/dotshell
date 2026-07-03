pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs

// Core compositor abstraction. Auto-detects the active compositor (sway/niri)
// and provides command helpers so modules don't hardcode compositor commands.
Singleton {
  id: compositor

  // Detected compositor from environment ("sway" or "niri").
  // When no env vars are set, defaults to "sway" so QML bindings that switch
  // on backend keep working — but `detected` will be false and command
  // helpers below will no-op + warn instead of firing swaymsg blindly.
  readonly property string resolvedBackend: {
    if (Quickshell.env("SWAYSOCK") || Quickshell.env("I3SOCK")) return "sway"
    if (Quickshell.env("NIRI_SOCKET")) return "niri"
    return "sway"
  }

  readonly property bool detected:
    Quickshell.env("SWAYSOCK") || Quickshell.env("I3SOCK") || Quickshell.env("NIRI_SOCKET")

  Component.onCompleted: {
    if (!detected) {
      console.warn("[Compositor] No SWAYSOCK / I3SOCK / NIRI_SOCKET set; compositor commands disabled.")
    }
  }

  function _skip(name) {
    if (detected) return false
    console.warn("[Compositor]", name, "skipped — no compositor detected.")
    return true
  }

  // Emitted when fetchOutputs() completes with JSON output data
  signal outputsFetched(string json)

  // Emitted when applyPosition() finishes (success or failure)
  signal positionApplied(bool success)

  // Rotate a display. transform values: "normal", "90", "180", "270"
  function setTransform(name, transform) {
    if (!name) return
    if (_skip("setTransform")) return
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
    if (_skip("focusWindow")) return
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
    if (_skip("applyPosition")) {
      compositor.positionApplied(false)
      return
    }
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
    if (_skip("fetchOutputs")) {
      compositor.outputsFetched("[]")
      return
    }
    if (resolvedBackend === "niri") {
      niriFetchProc.running = true
    } else {
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
    command: ["swaymsg", "-t", "get_outputs"]
    running: false
    stdout: StdioCollector {}
    onExited: (exitCode) => {
      if (exitCode === 0) {
        compositor.outputsFetched(swayFetchProc.stdout.text)
      }
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
    command: ["niri", "msg", "-j", "outputs"]
    running: false
    stdout: StdioCollector {}
    onExited: (exitCode) => {
      if (exitCode === 0) {
        compositor.outputsFetched(niriFetchProc.stdout.text)
      }
    }
  }
}
