pragma Singleton

import Quickshell
import Quickshell.I3
import Quickshell.Io
import QtQuick
import qs

Singleton {
  id: screenManager

  // Core-owned state: primary-screen selection drives popup/overlay
  // placement, not the display module (its UI merely calls setPrimary).
  ModuleConfig {
    moduleId: "screens"
    adapter: JsonAdapter {
      id: adapter
      // Stable display identifier: "model:serialNumber", or connector name
      // when Quickshell does not expose usable monitor metadata.
      // Empty string means "no preference" -> use first available screen.
      property string primaryDisplayId: ""
    }
  }

  function screenId(screen) {
    if (!screen) return ""
    var model = screen.model || ""
    var serial = screen.serialNumber || ""
    // ponytail: Connector fallback can change across ports; use compositor
    // identity if ScreenManager gains a core-safe metadata source.
    if (!model || model === "Unknown" || !serial || serial === "Unknown")
      return screen.name
    return model + ":" + serial
  }

  function friendlyName(screen, fallbackModel) {
    if (!screen) return ""
    if (screen.name.startsWith("eDP")) return "Built-in Display"
    var model = screen.model || ""
    if (!model || model === "Unknown") model = fallbackModel || ""
    return model || screen.name
  }

  // The persisted primary display ID
  readonly property string primaryDisplayId: adapter.primaryDisplayId

  // The resolved primary screen object (with fallback)
  readonly property var primaryScreen: {
    var screens = Quickshell.screens
    if (screens.length === 0) return null

    // If no preference set, use first screen
    if (adapter.primaryDisplayId === "") return screens[0]

    // Find the saved primary among connected screens
    for (var i = 0; i < screens.length; i++) {
      if (screenId(screens[i]) === adapter.primaryDisplayId) {
        return screens[i]
      }
    }

    // Fallback: saved primary not connected, use first available
    return screens[0]
  }

  readonly property var focusedScreen: {
    var focusedName = Compositor.resolvedBackend === "niri"
      ? Compositor.focusedOutputName
      : (I3.focusedMonitor ? I3.focusedMonitor.name : "")
    var screens = Quickshell.screens
    for (var i = 0; i < screens.length; i++) {
      if (screens[i].name === focusedName) return screens[i]
    }
    return primaryScreen
  }

  // Check if a screen is the primary
  function isPrimary(screen) {
    if (!screen || !primaryScreen) return false
    return screenId(screen) === screenId(primaryScreen)
  }

  // Set a screen as the primary display and persist
  function setPrimary(screen) {
    if (!screen) return
    adapter.primaryDisplayId = screenId(screen)
  }
}
