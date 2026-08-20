import QtQuick
import qs
import qs.core.components

Item {
  id: segment
  property var screen
  property bool barFocused: false

  anchors.verticalCenter: parent.verticalCenter
  width: row.width
  height: row.height

  property bool showInBar: ActiveCollabManager.totalCount > 0

  Row {
    id: row
    spacing: 4

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: ""
      color: Theme.textPrimary
      font.pixelSize: 16
      font.family: "Symbols Nerd Font"
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: ActiveCollabManager.totalCount
      color: Theme.textPrimary
      font.pixelSize: 14
    }
  }

  MouseArea {
    id: hoverArea
    anchors.fill: parent
    hoverEnabled: true
  }

  TooltipBase {
    anchorItem: segment
    visible: hoverArea.containsMouse || segment.barFocused
    fixedWidth: 320

    Column {
      width: parent.width
      spacing: 8

      TooltipText {
        text: "ActiveCollab Sessions"
      }

      Rectangle {
        width: parent.width
        height: 1
        color: Theme.bgBorder
      }

      Repeater {
        model: ActiveCollabManager.runningTasks

        Column {
          required property var modelData
          width: parent.width
          spacing: 2

          Row {
            width: parent.width
            spacing: 8

            TooltipText {
              id: projectLabel
              anchors.verticalCenter: parent.verticalCenter
              text: modelData.project
              elide: Text.ElideRight
              width: parent.width - durationLabel.width - 8
            }

            TooltipText {
              id: durationLabel
              anchors.verticalCenter: parent.verticalCenter
              text: modelData.duration
              color: Theme.warning
            }
          }

          TooltipText {
            visible: modelData.sessionDescription !== ""
            text: modelData.sessionDescription
            color: Theme.textSecondary
            font.pixelSize: 12
            elide: Text.ElideRight
            width: parent.width
          }
        }
      }
    }
  }
}
