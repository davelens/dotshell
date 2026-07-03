import QtQuick
import QtQuick.Controls
import qs
import qs.core.components

SettingsPage {
  id: settingsRoot
  title: "System Updates"

  // System update section
  TitleText {
    text: settingsRoot.highlightText("System Update", settingsRoot.searchQuery)
    textFormat: Text.RichText
  }

  Rectangle {
    width: parent.width
    height: flatpakColumn.height + 24
    radius: 8
    color: Theme.bgCard

    Column {
      id: flatpakColumn
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: 12
      spacing: 12

      Row {
        width: parent.width
        spacing: 12

        SwitchToggle {
          anchors.verticalCenter: parent.verticalCenter
          checked: UpdatesManager.includeFlatpak
          onClicked: UpdatesManager.includeFlatpak = !UpdatesManager.includeFlatpak
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: "Include Flatpak in system update"
          color: Theme.textPrimary
          font.pixelSize: 14
        }
      }

      HelpText {
        width: parent.width
        text: "When enabled, the \"System Update\" action will also run <b>flatpak update</b> after the pacman and AUR upgrade."
        textFormat: Text.RichText
        wrapMode: Text.WordWrap
      }
    }
  }
}
