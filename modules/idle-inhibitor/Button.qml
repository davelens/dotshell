import Quickshell.Wayland
import QtQuick
import qs
import qs.core.components

BarButton {
  id: button

  required property var hostWindow

  icon: IdleInhibitorManager.inhibited ? "󰈈" : "󰈉"
  iconColor: IdleInhibitorManager.inhibited ? Theme.accent : Theme.textPrimary

  onClicked: IdleInhibitorManager.toggle()

  IdleInhibitor {
    window: button.hostWindow
    enabled: IdleInhibitorManager.inhibited
  }
}
