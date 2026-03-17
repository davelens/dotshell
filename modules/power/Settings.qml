import QtQuick
import QtQuick.Controls
import qs
import qs.core.components

ScrollView {
  id: settingsRoot
  anchors.fill: parent
  clip: true
  contentWidth: availableWidth

  // Search query passed from settings panel
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
      text: "Power Menu"
      color: Theme.textPrimary
      font.pixelSize: 24
      font.bold: true
    }

    // -- Commands section ---------------------------------------------------

    TitleText {
      text: settingsRoot.highlightText("Commands", settingsRoot.searchQuery)
      textFormat: Text.RichText
    }

    Rectangle {
      width: parent.width
      height: commandsColumn.height + 24
      radius: 8
      color: Theme.bgCard

      Column {
        id: commandsColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        spacing: 16

        HelpText {
          width: parent.width
          text: "Shell commands executed for each power action. Changes take effect immediately."
          wrapMode: Text.WordWrap
        }

        // Lock command
        Column {
          width: parent.width
          spacing: 6

          Text {
            text: "Lock"
            color: Theme.textPrimary
            font.pixelSize: 14
          }

          FocusTextInput {
            text: PowerManager.lockCommand
            placeholderText: "loginctl lock-session"
            onEditingFinished: function(value) {
              if (value) PowerManager.lockCommand = value
            }
          }
        }

        // Suspend command
        Column {
          width: parent.width
          spacing: 6

          Text {
            text: "Suspend"
            color: Theme.textPrimary
            font.pixelSize: 14
          }

          FocusTextInput {
            text: PowerManager.suspendCommand
            placeholderText: "systemctl suspend"
            onEditingFinished: function(value) {
              if (value) PowerManager.suspendCommand = value
            }
          }
        }

        // Logout command
        Column {
          width: parent.width
          spacing: 6

          Text {
            text: "Logout"
            color: Theme.textPrimary
            font.pixelSize: 14
          }

          FocusTextInput {
            text: PowerManager.logoutCommand
            placeholderText: "swaymsg exit"
            onEditingFinished: function(value) {
              if (value) PowerManager.logoutCommand = value
            }
          }
        }

        // Reboot command
        Column {
          width: parent.width
          spacing: 6

          Text {
            text: "Reboot"
            color: Theme.textPrimary
            font.pixelSize: 14
          }

          FocusTextInput {
            text: PowerManager.rebootCommand
            placeholderText: "systemctl reboot"
            onEditingFinished: function(value) {
              if (value) PowerManager.rebootCommand = value
            }
          }
        }

        // Shutdown command
        Column {
          width: parent.width
          spacing: 6

          Text {
            text: "Shutdown"
            color: Theme.textPrimary
            font.pixelSize: 14
          }

          FocusTextInput {
            text: PowerManager.shutdownCommand
            placeholderText: "systemctl poweroff"
            onEditingFinished: function(value) {
              if (value) PowerManager.shutdownCommand = value
            }
          }
        }
      }
    }
  }
}
