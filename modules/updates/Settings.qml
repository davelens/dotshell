import QtQuick
import QtQuick.Controls
import qs
import qs.core.components

ScrollView {
  id: settingsRoot
  anchors.fill: parent
  clip: true
  contentWidth: availableWidth

  // Search query passed from SettingsPanel
  property string searchQuery: ""

  // Highlight matching text with yellow background
  function highlightText(text, query) {
    if (!query) return text
    var lowerText = text.toLowerCase()
    var lowerQuery = query.toLowerCase()
    var idx = lowerText.indexOf(lowerQuery)
    if (idx === -1) return text
    var before = text.substring(0, idx)
    var match = text.substring(idx, idx + query.length)
    var after = text.substring(idx + query.length)
    return before + '<span style="background-color: ' + Theme.warning + '; color: ' + Theme.bgDeep + ';">' + match + '</span>' + after
  }

  Column {
    width: parent.width
    spacing: 20

    Text {
      text: "System Updates"
      color: Theme.textPrimary
      font.pixelSize: 24
      font.bold: true
    }

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
}
