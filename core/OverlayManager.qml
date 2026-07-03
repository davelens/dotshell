pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// Identity model for full-screen overlays (slide-in panels, power menu,
// settings). At most one overlay is active at a time; opening one closes
// the active popup and any other overlay. Managers bind their open state
// to isOpen() and route open/close/toggle through here, so mutual
// exclusion and bar-focus handling live in one place.
Singleton {
  id: overlayManager

  // Module id of the active overlay, or "" when none is open
  property string activeOverlay: ""

  // Optional payload passed by open() (e.g. { category: "notifications" })
  property var overlayContext: ({})

  // id → human label, filled by register() from each overlay's manager at
  // startup. Doubles as the known-id list for IPC validation; core holds
  // no module knowledge.
  property var registeredOverlays: ({})

  function register(id: string, label: string): void {
    var next = Object.assign({}, registeredOverlays)
    next[id] = label
    registeredOverlays = next
  }

  readonly property bool overlayOpen: activeOverlay !== ""

  // Fires on every open() call, including re-opens with a new context
  signal opened(string id)

  function isOpen(id: string): bool {
    return activeOverlay === id
  }

  function open(id: string, context: var): void {
    PopupManager.close()
    overlayContext = context || ({})
    activeOverlay = id
    opened(id)
  }

  function close(id: string): void {
    // With an id, only close if that overlay is the active one
    if (id === undefined || id === "" || activeOverlay === id) activeOverlay = ""
  }

  function toggle(id: string): void {
    if (isOpen(id)) close(id)
    else open(id, undefined)
  }

  // One id-addressed IPC seam for every overlay; module-specific verbs
  // (dismiss, set, showCategory…) stay on their own targets.
  IpcHandler {
    target: "overlay"

    function toggle(id: string): string {
      var label = overlayManager.registeredOverlays[id]
      if (!label) return "error: unknown overlay '" + id + "'"
      overlayManager.toggle(id)
      return label + (overlayManager.isOpen(id) ? " opened" : " closed")
    }

    function open(id: string): string {
      var label = overlayManager.registeredOverlays[id]
      if (!label) return "error: unknown overlay '" + id + "'"
      overlayManager.open(id, undefined)
      return label + " opened"
    }

    function close(id: string): string {
      var label = overlayManager.registeredOverlays[id]
      if (!label) return "error: unknown overlay '" + id + "'"
      overlayManager.close(id)
      return label + " closed"
    }
  }
}
