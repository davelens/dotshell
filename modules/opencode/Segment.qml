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

  property bool showInBar: OpencodeManager.totalCount > 0

  Row {
    id: row
    spacing: 4

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: "󰚩"
      color: Theme.textPrimary
      font.pixelSize: 16
      font.family: "Symbols Nerd Font"
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: OpencodeManager.idleCount
      color: Theme.success
      font.pixelSize: 14
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: "/"
      color: Theme.textMuted
      font.pixelSize: 14
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: OpencodeManager.busyCount
      color: Theme.warning
      font.pixelSize: 14
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: "/"
      color: Theme.textMuted
      font.pixelSize: 14
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: OpencodeManager.errorCount
      color: Theme.danger
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
    fixedWidth: 280

    Column {
      width: parent.width
      spacing: 4

      Repeater {
        model: OpencodeManager.instances

        Row {
          required property var modelData
          width: parent.width
          spacing: 8

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: {
              if (modelData.status === "busy") return "󰝤"
              if (modelData.status === "idle") return "󰝦"
              return "󰝤"
            }
            color: {
              if (modelData.status === "busy") return Theme.warning
              if (modelData.status === "idle") return Theme.success
              if (modelData.status === "error") return Theme.danger
              return Theme.textMuted
            }
            font.pixelSize: 14
            font.family: "Symbols Nerd Font"
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: modelData.project
            color: Theme.textPrimary
            font.pixelSize: 14
            elide: Text.ElideRight
            width: parent.width - 70
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: modelData.status
            color: {
              if (modelData.status === "busy") return Theme.warning
              if (modelData.status === "idle") return Theme.success
              if (modelData.status === "error") return Theme.danger
              return Theme.textMuted
            }
            font.pixelSize: 14
            horizontalAlignment: Text.AlignRight
          }
        }
      }
    }
  }
}
