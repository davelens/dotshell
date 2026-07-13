import QtQuick
import QtQuick.Controls
import qs
import qs.core.components

SettingsPage {
  id: settingsRoot
  title: "Power Menu"

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
          placeholderText: "loginctl suspend"
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
          placeholderText: "loginctl reboot"
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
          placeholderText: "loginctl poweroff"
          onEditingFinished: function(value) {
            if (value) PowerManager.shutdownCommand = value
          }
        }
      }
    }
  }
}
