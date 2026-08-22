pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs

Singleton {
  id: popupManager

  property string activePopup: ""
  property var targetScreen: null

  // Anchor position for popup placement (screen-space X of the button's right edge)
  property real anchorRight: 0

  // Whether the anchor points at an actual bar button. False when a popup
  // is opened via IPC without its button in the statusbar; the stem
  // connector would point at nothing, so PopupBase hides it.
  property bool anchoredToButton: false

  property var registeredButtons: ({})

  function registerButton(name: string, button: var): void {
    registeredButtons[name] = button
  }

  function unregisterButton(name: string, button: var): void {
    if (registeredButtons[name] === button) delete registeredButtons[name]
  }

  function getButtonAnchor(name: string, screen: var): var {
    var button = registeredButtons[name]
    if (!button || button.screen !== screen || !button.visible
        || (button.showInBar !== undefined && !button.showInBar)) return null
    var mapped = button.mapToItem(null, button.width, 0)
    return mapped.x > button.width ? mapped.x : null
  }

  function toggle(name: string, buttonRight: real, screen: var): void {
    if (activePopup === name) {
      close()
    } else {
      OverlayManager.close("")
      targetScreen = screen || ScreenManager.primaryScreen
      activePopup = name
      anchorRight = buttonRight
      anchoredToButton = true
    }
  }

  function close(): void {
    activePopup = ""
  }

  function isOpen(name: string): bool {
    return activePopup === name
  }

  // IPC handler for external control (e.g. qs ipc call popup toggle volume)
  IpcHandler {
    target: "popup"

    function toggle(name: string): string {
      if (ModuleRegistry.getPopupModuleIds().indexOf(name) === -1) {
        return "error: unknown popup '" + name + "'"
      }
      if (popupManager.activePopup === name) {
        popupManager.close()
        return "Popup '" + name + "' closed"
      }
      OverlayManager.close("")
      var screen = ScreenManager.focusedScreen || ScreenManager.primaryScreen
      if (screen) {
        var anchor = popupManager.getButtonAnchor(name, screen)
        popupManager.targetScreen = screen
        popupManager.activePopup = name
        popupManager.anchorRight = anchor !== null ? anchor : screen.width - 20
        popupManager.anchoredToButton = anchor !== null
      }
      return "Popup '" + name + "' opened"
    }
  }
}
