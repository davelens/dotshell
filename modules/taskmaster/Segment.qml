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

  property bool showInBar: TaskmasterManager.totalCount > 0

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
      text: TaskmasterManager.totalCount
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

      Text {
        text: "Taskmaster Sessions"
        color: Theme.textPrimary
        font.pixelSize: 14
      }

      Rectangle {
        width: parent.width
        height: 1
        color: Theme.bgBorder
      }

      Repeater {
        model: TaskmasterManager.runningTasks

        Column {
          required property var modelData
          width: parent.width
          spacing: 2

          Row {
            width: parent.width
            spacing: 8

            Text {
              id: projectLabel
              anchors.verticalCenter: parent.verticalCenter
              text: modelData.project
              color: Theme.textPrimary
              font.pixelSize: 14
              elide: Text.ElideRight
              width: parent.width - durationLabel.width - 8
            }

            Text {
              id: durationLabel
              anchors.verticalCenter: parent.verticalCenter
              text: modelData.duration
              color: Theme.warning
              font.pixelSize: 14
            }
          }

          Text {
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
