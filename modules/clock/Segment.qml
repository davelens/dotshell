import QtQuick
import "../.."
import "../../core/components"

Item {
  id: clock
  property var screen
  property bool barFocused: false

  anchors.verticalCenter: parent.verticalCenter
  width: timeText.width
  height: timeText.height

  Text {
    id: timeText
    text: Time.time
    color: Theme.textPrimary
    font.pixelSize: 14
  }

  MouseArea {
    id: hoverArea
    anchors.fill: parent
    hoverEnabled: true
  }

  TooltipBase {
    anchorItem: clock
    visible: hoverArea.containsMouse || clock.barFocused

    Text {
      text: Time.date
      color: Theme.textPrimary
      font.pixelSize: 14
    }
  }
}
