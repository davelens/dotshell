import Quickshell
import QtQuick
import qs
import qs.core.components

Variants {
  model: PopupManager.isOpen("display") && ScreenManager.primaryScreen
         ? [ScreenManager.primaryScreen] : []

  PopupBase {
    popupWidth: 320
    contentSpacing: 12

    // Header with configure link
    Item {
      width: parent.width
      height: 20

      Text {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: "Main display"
        color: Theme.textPrimary
        font.pixelSize: 16
      }

      FocusLink {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: "Configure"
        textColor: Theme.textMuted
        hoverColor: Theme.accent
        fontSize: 12
        onClicked: DisplayConfig.openSettings()
      }
    }

    // Display list
    Column {
      width: parent.width
      spacing: 4

      Repeater {
        model: Quickshell.screens

        FocusListItem {
          required property var modelData

          itemHeight: 48
          bodyMargins: 0
          bodyRadius: 4
          icon: modelData.name.startsWith("eDP") ? "󰌢" : "󰍹"
          iconSize: 18
          iconColor: ScreenManager.isPrimary(modelData) ? Theme.accent : Theme.textPrimary
          text: ScreenManager.friendlyName(modelData)
          fontSize: 14
          subtitle: modelData.name
          subtitleFontSize: 11
          rightIcon: ScreenManager.isPrimary(modelData) ? "󰄬" : ""
          rightIconColor: Theme.accent
          rightIconHoverColor: Theme.accent
          backgroundColor: Theme.bgCard
          hoverBackgroundColor: Theme.bgCardHover
          onClicked: {
            ScreenManager.setPrimary(modelData)
            PopupManager.close()
          }
        }
      }
    }
  }
}
