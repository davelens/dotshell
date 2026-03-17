import QtQuick
import qs
import qs.core.components

BarButton {
  icon: "󰐥"
  iconColor: Theme.accent

  onClicked: PowerManager.toggle()
}
