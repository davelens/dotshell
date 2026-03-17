import QtQuick
import qs
import qs.core.components

Item {
  id: root
  property var screen
  property bool barFocused: false

  anchors.verticalCenter: parent.verticalCenter
  width: contentRow.width
  height: contentRow.height

  Row {
    id: contentRow
    spacing: 4

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: ""
      color: Theme.textPrimary
      font.pixelSize: 16
      font.family: "Symbols Nerd Font"
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: SystemLoadManager.cpuPercent + "%"
      color: Theme.textPrimary
      font.pixelSize: 14
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: "󰧑"
      color: Theme.textPrimary
      font.pixelSize: 16
      font.family: "Symbols Nerd Font"
      leftPadding: 6
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: SystemLoadManager.ramPercent + "%"
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
    anchorItem: root
    visible: hoverArea.containsMouse || root.barFocused

    Column {
      spacing: 4

      Text {
        text: "CPU: " + SystemLoadManager.cpuPercent + "%"
        color: Theme.textPrimary
        font.pixelSize: 14
      }

      Text {
        text: "Memory: " + SystemLoadManager.ramUsedGb.toFixed(1) + " / " + SystemLoadManager.ramTotalGb.toFixed(1) + " GB (" + SystemLoadManager.ramPercent + "%)"
        color: Theme.textPrimary
        font.pixelSize: 14
      }
    }
  }
}
