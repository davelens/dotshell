import QtQuick
import qs

Rectangle {
  id: tag

  property string text: ""
  property int fontSize: 13

  implicitWidth: tagText.implicitWidth + 12
  implicitHeight: tagText.implicitHeight + 6
  radius: 4
  color: Theme.bgCardHover
  border.width: 1
  border.color: Theme.bgBorder

  Text {
    id: tagText
    anchors.centerIn: parent
    text: tag.text
    color: Theme.textPrimary
    font.family: "Hack Nerd Font"
    font.pixelSize: tag.fontSize
  }
}
