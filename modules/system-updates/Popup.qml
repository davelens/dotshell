import Quickshell
import QtQuick
import QtQuick.Controls
import qs
import qs.core.components

ModulePopup {
  id: updatesPopup

  PopupBase {
    id: popup
    popupWidth: 860
    popupRightMargin: SystemUpdatesManager.totalCount > 0 ? -1 : 20
    contentSpacing: 12
    stemEnabled: SystemUpdatesManager.totalCount > 0

    property int maxVisibleItems: 12
    property int rowHeight: 28
    property int rowSpacing: 4
    readonly property int sourceCount: SystemUpdatesManager.sourceModels.length

    popupHeight: {
      var height = 28 + 12 + 32 + 12 + 1 + 12
      if (SystemUpdatesManager.checking) {
        height += 40
      } else if (SystemUpdatesManager.totalCount === 0) {
        height += 50
      } else {
        height += 20 + 8 + 26 + 8
        var maxItems = 1
        var sources = SystemUpdatesManager.sourceModels
        for (var i = 0; i < sources.length; i++) {
          maxItems = Math.max(maxItems, Math.min(sources[i].updates.length, maxVisibleItems))
        }
        height += maxItems * rowHeight + (maxItems - 1) * rowSpacing
      }
      return height + 48
    }

    Item {
      width: parent.width
      height: 28

      Row {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: SystemUpdatesManager.getIcon()
          color: SystemUpdatesManager.totalCount > 0 ? Theme.success : Theme.textMuted
          font.pixelSize: 20
          font.family: "Symbols Nerd Font"
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: "System Updates"
          color: Theme.textPrimary
          font.family: Theme.fontFamily
          font.pixelSize: 16
        }
      }

      Row {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: "󰑐"
          color: refreshArea.containsMouse ? Theme.accent : Theme.textMuted
          font.pixelSize: 16
          font.family: "Symbols Nerd Font"
          visible: !SystemUpdatesManager.checking

          MouseArea {
            id: refreshArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: SystemUpdatesManager.checkUpdates()
          }
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: "󰔿"
          color: Theme.accent
          font.pixelSize: 16
          font.family: "Symbols Nerd Font"
          visible: SystemUpdatesManager.checking

          RotationAnimation on rotation {
            running: SystemUpdatesManager.checking
            from: 0
            to: 360
            duration: 1000
            loops: Animation.Infinite
          }
        }
      }
    }

    Item {
      width: parent.width
      height: 32

      FocusButton {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: SystemUpdatesManager.systemUpdating ? "Updating system..." : "System Update"
        width: 160
        height: 28
        backgroundColor: SystemUpdatesManager.totalCount > 0 && !SystemUpdatesManager.systemUpdating ? Theme.success : Theme.bgCardHover
        textColor: SystemUpdatesManager.totalCount > 0 && !SystemUpdatesManager.systemUpdating ? Theme.bgDeep : Theme.textMuted
        hoverColor: SystemUpdatesManager.totalCount > 0 && !SystemUpdatesManager.systemUpdating ? Theme.activeIndicator : Theme.bgBorder
        enabled: SystemUpdatesManager.totalCount > 0 && !SystemUpdatesManager.systemUpdating && !SystemUpdatesManager.checking
        opacity: enabled ? 1.0 : 0.5
        onClicked: SystemUpdatesManager.systemUpdate()
      }

      Text {
        anchors.left: parent.left
        anchors.leftMargin: 170
        anchors.verticalCenter: parent.verticalCenter
        text: SystemUpdatesManager.systemUpdateDescription
          + (SystemUpdatesManager.includeFlatpak ? " + Flatpak" : "")
        color: Theme.textMuted
        font.family: Theme.fontFamily
        font.pixelSize: 12
        visible: !SystemUpdatesManager.systemUpdating
      }

      Text {
        anchors.left: parent.left
        anchors.leftMargin: 170
        anchors.verticalCenter: parent.verticalCenter
        text: SystemUpdatesManager.systemUpdateRunningDescription
          + (SystemUpdatesManager.includeFlatpak ? " followed by Flatpak" : "")
          + "... All other updates are blocked."
        color: Theme.warning
        font.family: Theme.fontFamily
        font.pixelSize: 12
        visible: SystemUpdatesManager.systemUpdating
      }
    }

    Rectangle {
      width: parent.width
      height: 1
      color: Theme.bgCardHover
    }

    Item {
      width: parent.width
      height: 40
      visible: SystemUpdatesManager.checking

      Text {
        anchors.centerIn: parent
        text: "Checking for updates..."
        color: Theme.textMuted
        font.family: Theme.fontFamily
        font.pixelSize: 14
      }
    }

    Column {
      width: parent.width
      spacing: 8
      visible: !SystemUpdatesManager.checking && SystemUpdatesManager.totalCount === 0

      Text {
        width: parent.width
        text: SystemUpdatesManager.backendSupported ? "System is up to date" : "No supported system package backend"
        color: Theme.textMuted
        font.family: Theme.fontFamily
        font.pixelSize: 15
        horizontalAlignment: Text.AlignHCenter
        topPadding: 8
      }

      Text {
        width: parent.width
        text: SystemUpdatesManager.backendSupported
          ? "No pending updates"
          : "Flatpak updates remain available when Flatpak is installed"
        color: Theme.textSubtle
        font.family: Theme.fontFamily
        font.pixelSize: 13
        horizontalAlignment: Text.AlignHCenter
        bottomPadding: 8
      }
    }

    Row {
      id: sourceRow
      width: parent.width
      spacing: 12
      visible: !SystemUpdatesManager.checking && SystemUpdatesManager.totalCount > 0
      // Each additional source adds outer spacing, a 1px separator, and inner spacing.
      readonly property real sourceColumnWidth: (width - Math.max(0, popup.sourceCount - 1) * 25) / popup.sourceCount

      Repeater {
        model: SystemUpdatesManager.sourceModels

        Row {
          required property var modelData
          required property int index
          spacing: 12

          Rectangle {
            visible: index > 0
            width: visible ? 1 : 0
            height: parent.height
            color: Theme.bgCardHover
          }

          SourceColumn {
            sourceId: parent.modelData.id
            label: parent.modelData.label
            updates: parent.modelData.updates
            columnWidth: sourceRow.sourceColumnWidth
            maxVisibleItems: popup.maxVisibleItems
            rowHeight: popup.rowHeight
            rowSpacing: popup.rowSpacing
          }
        }
      }
    }
  }
}
