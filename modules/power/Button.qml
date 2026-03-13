import QtQuick
import "../.."
import "../../core/components"

BarButton {
  icon: "󰐥"
  iconColor: Theme.accent

  onClicked: PowerManager.toggle()
}
