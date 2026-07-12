pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs

Singleton {
  id: manager

  // Persisted settings (defaults live on the adapter below)
  property alias backend: adapter.backend
  property alias autoDetect: adapter.autoDetect
  property alias displayMode: adapter.displayMode
  property alias count: adapter.count
  property alias icons: adapter.icons

  // Resolved backend name ("sway" or "niri") based on user override or core auto-detection
  readonly property string resolvedBackend: backend !== "auto" ? backend : Compositor.resolvedBackend

  ModuleConfig {
    moduleId: "workspaces"
    adapter: JsonAdapter {
      id: adapter
      property string backend: "auto"
      property bool autoDetect: true
      property string displayMode: "numbers"
      property int count: 6
      property var icons: ({
        "1": "",
        "2": "󰈹",
        "3": "",
        "4": "󰙯",
        "5": "󰎇",
        "6": ""
      })
    }
  }

  function setBackend(value) {
    adapter.backend = value
  }

  function setAutoDetect(enabled) {
    adapter.autoDetect = enabled
  }

  function setDisplayMode(mode) {
    adapter.displayMode = mode
  }

  function setCount(n) {
    adapter.count = Math.max(1, Math.min(10, n))
  }

  function setIcon(workspace, icon) {
    var updated = Object.assign({}, adapter.icons)
    updated[workspace] = icon
    adapter.icons = updated
  }
}
