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

  property bool showInBar: AiAgentsMonitorManager.totalCount > 0

  Row {
    id: row
    spacing: 4

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: "󰚩"
      color: Theme.textPrimary
      font.pixelSize: Theme.scaledFontSize(16)
      font.family: "Symbols Nerd Font"
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: AiAgentsMonitorManager.idleCount
      color: Theme.success
      font.family: Theme.fontFamily
      font.pixelSize: Theme.scaledFontSize(14)
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: "/"
      color: Theme.textMuted
      font.family: Theme.fontFamily
      font.pixelSize: Theme.scaledFontSize(14)
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: AiAgentsMonitorManager.busyCount
      color: Theme.warning
      font.family: Theme.fontFamily
      font.pixelSize: Theme.scaledFontSize(14)
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: "/"
      color: Theme.textMuted
      font.family: Theme.fontFamily
      font.pixelSize: Theme.scaledFontSize(14)
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: AiAgentsMonitorManager.errorCount + AiAgentsMonitorManager.questionCount
      color: Theme.danger
      font.family: Theme.fontFamily
      font.pixelSize: Theme.scaledFontSize(14)
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
    fixedWidth: 400
    horizontalPadding: 40
    verticalPadding: 24

    Column {
      width: parent.width
      spacing: 8

      TooltipText {
        text: "AI Agent Sessions"
      }

      Rectangle {
        width: parent.width
        height: 1
        color: Theme.bgBorder
      }

      Repeater {
        model: AiAgentsMonitorManager.instances

        Column {
          required property var modelData
          width: parent.width
          spacing: 2

          Row {
            width: parent.width
            spacing: 8

            TooltipText {
              id: statusIcon
              anchors.verticalCenter: parent.verticalCenter
              text: {
                if (modelData.status === "busy") return "󰝤"
                if (modelData.status === "idle") return "󰝦"
                if (modelData.status === "input") return ""
                return "󰝤"
              }
              color: {
                if (modelData.status === "busy") return Theme.warning
                if (modelData.status === "idle") return Theme.success
                if (modelData.status === "error" || modelData.status === "input") return Theme.danger
                return Theme.textMuted
              }
              font.family: "Symbols Nerd Font"
            }

            TooltipText {
              id: providerLabel
              anchors.verticalCenter: parent.verticalCenter
              width: 18
              horizontalAlignment: Text.AlignLeft
              text: {
                if (modelData.provider === "opencode") return "OC"
                if (modelData.provider === "claude-code") return "CC"
                if (modelData.provider === "pi") return "PI"
                return "??"
              }
              color: Theme.textMuted
              font.pixelSize: Theme.scaledFontSize(12)
            }

            TooltipText {
              anchors.verticalCenter: parent.verticalCenter
              text: modelData.remote
                ? modelData.project + " @" + modelData.source
                : modelData.project
              textFormat: Text.PlainText
              elide: Text.ElideRight
              width: parent.width - statusIcon.width - providerLabel.width - statusLabel.width - 24
            }

            TooltipText {
              id: statusLabel
              anchors.verticalCenter: parent.verticalCenter
              text: modelData.status
              color: {
                if (modelData.status === "busy") return Theme.warning
                if (modelData.status === "idle") return Theme.success
                if (modelData.status === "error" || modelData.status === "input") return Theme.danger
                return Theme.textMuted
              }
              width: 38
              horizontalAlignment: Text.AlignRight
            }
          }

          TooltipText {
            visible: modelData.sessionTitle !== ""
            text: modelData.sessionTitle
            color: Theme.textSecondary
            font.pixelSize: Theme.scaledFontSize(12)
            textFormat: Text.PlainText
            elide: Text.ElideRight
            width: parent.width
            leftPadding: statusIcon.width + providerLabel.width + 16
          }
        }
      }

      TooltipText {
        visible: AiAgentsMonitorManager.remoteConfigured
          && AiAgentsMonitorManager.remoteState !== "connected"
        text: AiAgentsMonitorManager.remoteHost
          + (AiAgentsMonitorManager.remoteState === "connecting"
            ? ": connecting\u2026"
            : ": unavailable")
        color: Theme.textMuted
        font.pixelSize: Theme.scaledFontSize(12)
        textFormat: Text.PlainText
        elide: Text.ElideRight
        width: parent.width
      }
    }
  }
}
