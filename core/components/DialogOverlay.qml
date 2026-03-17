import QtQuick
import qs

FocusScope {
  id: overlay
  anchors.fill: parent

  required property string title
  signal closeRequested()
  default property alias content: contentColumn.data

  // Handle Ctrl+[ and Escape to close the dialog
  Keys.onPressed: event => {
    if (event.key === Qt.Key_Escape
        || (event.key === Qt.Key_BracketLeft && (event.modifiers & Qt.ControlModifier))) {
      overlay.closeRequested()
      event.accepted = true
    }
  }

  Rectangle {
    anchors.fill: parent
    color: Theme.bgBase
    radius: 8
  }

  // Absorb clicks so they don't pass through to the backdrop
  MouseArea {
    anchors.fill: parent
    onClicked: {}
  }

  // Border
  Rectangle {
    anchors.fill: parent
    color: "transparent"
    border.width: 1
    border.color: Theme.bgBorder
    radius: 8
    z: 100
  }

  Column {
    id: contentColumn
    anchors.fill: parent
    anchors.margins: 24
    spacing: 16

    // Header with title and close button
    Item {
      width: parent.width
      height: 24

      Text {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: overlay.title
        color: Theme.textPrimary
        font.pixelSize: 20
        font.bold: true
      }

      Text {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: "✕"
        color: closeHover.containsMouse ? Theme.textPrimary : Theme.textMuted
        font.pixelSize: 16

        MouseArea {
          id: closeHover
          anchors.fill: parent
          anchors.margins: -6
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: overlay.closeRequested()
        }
      }
    }
  }
}
