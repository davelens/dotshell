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
  property string focusedOutputName: ""

  Component.onCompleted: {
    if (!detected) {
      console.warn("[Compositor] No SWAYSOCK / I3SOCK / NIRI_SOCKET set; compositor commands disabled.")
    } else if (resolvedBackend === "niri") {
      refreshFocusedOutput()
      niriEventProc.running = true
    }
  }

  function _skip(name) {
    if (detected) return false
    console.warn("[Compositor]", name, "skipped — no compositor detected.")
    return true
  }

  // Emitted when fetchOutputs() completes with JSON output data
  signal outputsFetched(string json)

  // Emitted when output mutations finish (success or failure)
  signal positionApplied(bool success)
  signal scaleApplied(string name, bool success)
  signal outputPowerApplied(string name, bool success)
  signal workspaceMoved(string outputName, bool success)

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

  // Set one output's render scale.
  function applyScale(name, scale) {
    if (!name) return
    if (_skip("applyScale")) {
      compositor.scaleApplied(name, false)
      return
    }
    scaleProc.outputName = name
    scaleProc.command = resolvedBackend === "niri"
      ? ["niri", "msg", "output", name, "scale", String(scale)]
      : ["swaymsg", "output", name, "scale", String(scale)]
    scaleProc.running = true
  }

  // Enable or disable one output.
  function setOutputActive(name, active) {
    if (!name) return
    if (_skip("setOutputActive")) {
      compositor.outputPowerApplied(name, false)
      return
    }
    outputPowerProc.outputName = name
    outputPowerProc.command = resolvedBackend === "niri"
      ? ["niri", "msg", "output", name, active ? "on" : "off"]
      : ["swaymsg", "output", name, active ? "enable" : "disable"]
    outputPowerProc.running = true
  }

  function moveFocusedWorkspaceToOutput(name) {
    if (!name) return
    if (_skip("moveFocusedWorkspaceToOutput")) {
      compositor.workspaceMoved(name, false)
      return
    }
    workspaceMoveProc.outputName = name
    workspaceMoveProc.command = resolvedBackend === "niri"
      ? ["niri", "msg", "action", "move-workspace-to-monitor", name]
      : ["swaymsg", "move", "workspace", "to", "output", name]
    workspaceMoveProc.running = true
  }

  function refreshFocusedOutput() {
    if (resolvedBackend === "niri" && !niriFocusedOutputProc.running)
      niriFocusedOutputProc.running = true
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

  Process {
    id: scaleProc
    property string outputName: ""
    onExited: exitCode => {
      var success = exitCode === 0
      compositor.scaleApplied(outputName, success)
      if (success) compositor.fetchOutputs()
    }
  }

  Process {
    id: outputPowerProc
    property string outputName: ""
    onExited: exitCode => {
      var success = exitCode === 0
      compositor.outputPowerApplied(outputName, success)
      if (success) compositor.fetchOutputs()
    }
  }

  Process {
    id: workspaceMoveProc
    property string outputName: ""
    onExited: exitCode => {
      var success = exitCode === 0
      compositor.workspaceMoved(outputName, success)
      if (success) compositor.fetchOutputs()
    }
  }

  // Sway processes
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
    id: niriFocusProc
    running: false
  }

  Process {
    id: niriFocusedOutputProc
    command: ["niri", "msg", "-j", "focused-output"]
    stdout: StdioCollector {}
    onExited: exitCode => {
      if (exitCode !== 0) return
      try {
        var output = JSON.parse(stdout.text)
        compositor.focusedOutputName = output ? output.name || "" : ""
      } catch (e) {
        console.warn("[Compositor] Failed to parse Niri focused output:", e)
      }
    }
  }

  Process {
    id: niriEventProc
    command: ["niri", "msg", "-j", "event-stream"]
    stdout: SplitParser {
      onRead: line => {
        if (line.indexOf("WorkspacesChanged") >= 0 || line.indexOf("WorkspaceActivated") >= 0)
          compositor.refreshFocusedOutput()
      }
    }
    onExited: niriEventRestart.start()
  }

  Timer {
    id: niriEventRestart
    interval: 2000
    onTriggered: {
      if (compositor.resolvedBackend === "niri") niriEventProc.running = true
    }
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
