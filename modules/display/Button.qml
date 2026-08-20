import Quickshell
import QtQuick
import qs
import qs.core.components

BarButton {
  icon: "󰍹"

  onWheel: event => {
    if (!DisplayManager.brightnessAvailable) return
    DisplayManager.adjustBrightness(event.angleDelta.y > 0 ? 1 : -1)
  }
}
