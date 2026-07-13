import Quickshell
import Quickshell.Wayland
import QtQuick
import qs

// Full-screen overlay PanelWindow for module panels: covers the screen,
// ignores exclusion zones, and takes exclusive keyboard focus while open.
// Use as the Variants delegate gated on the module's overlay state.
PanelWindow {
  id: panelBase

  required property var modelData

  // Compositor-visible layer-shell namespace
  property string namespaceName: "dotshell-panel"

  screen: modelData
  visible: true

  anchors {
    top: true
    left: true
    right: true
    bottom: true
  }

  color: Theme.overlay
  exclusionMode: ExclusionMode.Ignore

  WlrLayershell.namespace: panelBase.namespaceName
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
}
