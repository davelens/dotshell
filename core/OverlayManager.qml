pragma Singleton

import QtQuick
import Quickshell
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
}
