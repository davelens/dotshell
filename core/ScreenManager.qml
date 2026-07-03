pragma Singleton

import Quickshell
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
      // Stable display identifier: "model:serialNumber"
      // Empty string means "no preference" -> use first available screen
      property string primaryDisplayId: ""
    }
  }

  // Stable identifier for a ShellScreen: "model:serialNumber"
  function screenId(screen) {
    if (!screen) return ""
    return screen.model + ":" + screen.serialNumber
  }

  // Human-friendly name for a ShellScreen
  // eDP connectors -> "Built-in Display", externals -> model name
  function friendlyName(screen) {
    if (!screen) return ""
    if (screen.name.startsWith("eDP")) return "Built-in Display"
    return screen.model || screen.name
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
