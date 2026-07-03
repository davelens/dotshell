pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs

Singleton {
  id: popupManager

  property string activePopup: ""

  // Screen that opened the popup
  property var activePopupScreen: null

  // Anchor position for popup placement (screen-space X of the button's right edge)
  property real anchorRight: 0

  // Whether the anchor points at an actual bar button. False when a popup
  // is opened via IPC without its button in the statusbar; the stem
  // connector would point at nothing, so PopupBase hides it.
  property bool anchoredToButton: false

  // Registered button references per popup (for IPC toggle anchor computation)
  property var registeredButtons: ({})

  // Legacy stored anchors (kept as fallback)
  property var storedAnchors: ({})

  // Register a button for a popup (called from BarButton)
  function registerButton(name: string, buttonRef: var): void {
    var buttons = Object.assign({}, registeredButtons)
    buttons[name] = buttonRef
    registeredButtons = buttons
  }

  // Compute anchor position from a registered button
  function getButtonAnchor(name: string): var {
    var btn = registeredButtons[name]
    if (btn && btn.screen) {
      var mapped = btn.mapToItem(null, btn.width, 0)
      if (mapped.x > btn.width) {
        return { screen: btn.screen, right: mapped.x }
      }
    }
    return null
  }

  function toggle(name: string, screen: var, buttonRight: real): void {
    if (activePopup === name && activePopupScreen === screen) {
      close()
    } else {
      OverlayManager.close("")
      activePopup = name
      activePopupScreen = screen
      anchorRight = buttonRight
      anchoredToButton = true
    }
  }

  function close(): void {
    activePopup = ""
    activePopupScreen = null
  }

  function isOpen(name: string): bool {
    return activePopup === name
  }

  // IPC handler for external control (e.g. qs ipc call popup toggle volume)
  IpcHandler {
    target: "popup"

    function toggle(name: string): string {
      if (popupManager.activePopup === name) {
        popupManager.close()
        return "Popup '" + name + "' closed"
      }
      OverlayManager.close("")
      // Compute anchor from the registered button at toggle time
      var anchor = popupManager.getButtonAnchor(name)
      if (anchor) {
        popupManager.activePopup = name
        popupManager.activePopupScreen = anchor.screen
        popupManager.anchorRight = anchor.right
        popupManager.anchoredToButton = true
      } else if (ScreenManager.primaryScreen) {
        popupManager.activePopup = name
        popupManager.activePopupScreen = ScreenManager.primaryScreen
        // Right margin matches the 20px gap between statusbar and popup top
        popupManager.anchorRight = ScreenManager.primaryScreen.width - 20
        popupManager.anchoredToButton = false
      }
      return "Popup '" + name + "' opened"
    }
  }
}
