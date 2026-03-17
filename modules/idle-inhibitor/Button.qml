import QtQuick
import qs
import qs.core.components

BarButton {
  id: button

  icon: IdleInhibitorManager.inhibited ? "󰈈" : "󰈉"
  iconColor: IdleInhibitorManager.inhibited ? Theme.accent : Theme.textPrimary

  onClicked: {
    IdleInhibitorManager.toggle()
  }
}
