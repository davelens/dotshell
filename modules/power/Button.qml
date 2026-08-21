import QtQuick
import qs
import qs.core.components

BarButton {
  id: button

  icon: "󰐥"
  iconColor: Theme.accent

  onClicked: OverlayManager.toggle("power", button.screen)
}
